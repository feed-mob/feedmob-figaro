# Failure cases: dependency resolution; removed Ruby/Bundler APIs; Psych aliases;
# boot ordering; external ENV precedence; development/SKIP_APOLLO network access;
# production Apollo/default+custom files; standalone CLI loading and arguments.
require "bundler/setup"
require "json"
require "tmpdir"
require "fileutils"
require "open3"
require "rbconfig"
require "socket"
require "timeout"

ROOT = File.expand_path("..", __dir__)
RESULTS = []

def check(name)
  yield
  RESULTS << { name: name, passed: true }
  puts "PASS #{name}"
end

def assert(value, message)
  raise message unless value
end

def run(dir, code, env = {})
  clean = ENV.keys.grep(/\A(?:APOLLO_|SKIP_APOLLO|_FIGARO_|FIGARO_CHECK_)/).to_h { |key| [key, nil] }
  stdout, stderr, status = Timeout.timeout(60) do
    Open3.capture3(clean.merge(env), RbConfig.ruby, "-I", File.join(ROOT, "lib"), "-e", code, chdir: dir)
  end
  assert(status.success?, "Subprocess failed:\n#{stdout}\n#{stderr}")
  stdout
end

Dir.mktmpdir("figaro-compatibility-") do |dir|
  FileUtils.mkdir_p(File.join(dir, "config"))
  File.write(File.join(dir, ".gitignore"), "/existing\n")
  check("CLI install and gitignore") do
    run(dir, "ARGV.replace(['install']); load #{File.join(ROOT, 'bin/figaro').inspect}")
    assert(File.file?(File.join(dir, "config/application.yml")), "Missing generated configuration")
    assert(File.read(File.join(dir, ".gitignore")).include?("/config/application.yml"), "Missing gitignore entry")
  end
  check("CLI custom path") do
    run(dir, "ARGV.replace(['install', '-p', 'custom.yml']); load #{File.join(ROOT, 'bin/figaro').inspect}")
    assert(File.file?(File.join(dir, "custom.yml")), "Missing custom configuration")
  end

  File.write(File.join(dir, "config/application.yml"), <<~YAML)
    defaults: &defaults
      FIGARO_CHECK_VALUE: local
      FIGARO_CHECK_PRIORITY: yaml
    development:
      <<: *defaults
      FIGARO_CHECK_ERB: <%= "erb".upcase %>
    production:
      <<: *defaults
  YAML
  boot = <<~'CODE'
    require "logger"
    require "rails"
    require "action_controller/railtie"
    require "figaro"
    require "json"
    class CompatibilityApp < Rails::Application
      config.root = Dir.pwd
      config.eager_load = false
      config.secret_key_base = "compatibility-check-only" * 4
      config.hosts.clear if config.respond_to?(:hosts)
      config.logger = Logger.new($stderr)
      config.observed_before_initialization = ENV["FIGARO_CHECK_VALUE"]
    end
    Rails.application.initialize!
    class ProbeController < ActionController::Base
      def show
        render json: {
          value: ENV["FIGARO_CHECK_VALUE"], priority: ENV["FIGARO_CHECK_PRIORITY"],
          erb: ENV["FIGARO_CHECK_ERB"], before: Rails.application.config.observed_before_initialization
        }
      end
    end
    Rails.application.routes.draw { get "/probe", to: "probe#show" }
    response = Rack::MockRequest.new(Rails.application).get("http://localhost/probe")
    raise "HTTP #{response.status}" unless response.status == 200
    puts "RESULT:" + response.body
  CODE
  check("Development boot, aliases, ERB, early config and external ENV priority") do
    output = run(dir, boot, "RAILS_ENV" => "development", "FIGARO_CHECK_PRIORITY" => "external", "APOLLO_HOST" => "http://127.0.0.1:1", "APOLLO_APP_ID" => "fixture", "APOLLO_CLUSTER" => "default")
    result = JSON.parse(output.lines.grep(/^RESULT:/).last.delete_prefix("RESULT:"))
    assert(result == { "value" => "local", "priority" => "external", "erb" => "ERB", "before" => "local" }, "Incorrect boot configuration")
    assert(!output.include?("[Apollo]"), "Development attempted Apollo")
  end
  check("Production SKIP_APOLLO boot without network") do
    output = run(dir, boot, "RAILS_ENV" => "production", "SKIP_APOLLO" => "true", "APOLLO_HOST" => "http://127.0.0.1:1", "APOLLO_APP_ID" => "fixture", "APOLLO_CLUSTER" => "default")
    assert(output.include?('"value":"local"'), "Local configuration was not loaded")
    assert(!output.include?("[Apollo]"), "SKIP_APOLLO attempted remote access")
  end

  server = TCPServer.new("127.0.0.1", 0)
  paths = []
  responder = Thread.new do
    3.times do
      client = server.accept
      path = client.gets.split[1]
      paths << path
      while (line = client.gets) && line != "\r\n"; end
      content = path.end_with?("application.yml") ? "FIGARO_CHECK_VALUE: remote\nFIGARO_CHECK_PRIORITY: remote\n" : "fixture: true\n"
      body = JSON.generate("configurations" => { "content" => content }, "releaseKey" => "fixture")
      client.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
      client.close
    end
  end
  begin
    check("Production Apollo boot with default and custom files") do
      File.write(File.join(dir, "config/apollo.yml"), <<~YAML)
        APOLLO_HOST: "http://127.0.0.1:#{server.addr[1]}"
        APOLLO_APP_ID: fixture
        APOLLO_CLUSTER: default
        APOLLO_CUSTOM_CONFIG_FILE: '["extra.yml"]'
      YAML
      output = run(dir, boot, "RAILS_ENV" => "production", "FIGARO_CHECK_PRIORITY" => "external")
      assert(responder.join(5), "Incomplete Apollo requests")
      assert(paths == %w[application.yml sidekiq.yml extra.yml].map { |file| "/configs/fixture/default/#{file}" }, "Wrong namespaces")
      result = JSON.parse(output.lines.grep(/^RESULT:/).last.delete_prefix("RESULT:"))
      assert(result.values_at("value", "before", "priority") == %w[remote remote external], "Incorrect Apollo boot values")
      assert(File.read(File.join(dir, "config/extra.yml")) == "fixture: true\n", "Missing custom file")
    end
  ensure
    responder.kill if responder.alive?
    responder.join
    server.close
  end

  check("CLI heroku:set under current Bundler with a local command stub") do
    FileUtils.mkdir_p(File.join(dir, "bin"))
    File.write(File.join(dir, "bin/heroku"), "#!/bin/sh\nprintf '%s\\n' \"$@\" > heroku-args.txt\n")
    File.chmod(0755, File.join(dir, "bin/heroku"))
    File.write(File.join(dir, "cli.yml"), "FIGARO_CHECK_VALUE: 'hello world'\n")
    run(dir, "require 'bundler'; ARGV.replace(['heroku:set', '-p', 'cli.yml', '-a', 'fixture']); load #{File.join(ROOT, 'bin/figaro').inspect}", "PATH" => "#{dir}/bin:#{ENV.fetch('PATH')}", "BUNDLER_ORIG_PATH" => "#{dir}/bin:#{ENV.fetch('PATH')}")
    args = File.readlines(File.join(dir, "heroku-args.txt"), chomp: true)
    assert(args == ["config:set", "FIGARO_CHECK_VALUE=hello world", "--app=fixture"], "Incorrect CLI arguments")
  end
end
FileUtils.mkdir_p(File.join(ROOT, "tmp"))
report = { ruby: RUBY_VERSION, rails: Gem.loaded_specs.fetch("rails").version.to_s, checks: RESULTS }
File.write(File.join(ROOT, "tmp/compatibility.json"), JSON.pretty_generate(report))
