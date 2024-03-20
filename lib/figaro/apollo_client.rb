require "net/http"

module Figaro
  class ApolloClient
    CONFIG_FILE = [
      'application.yml',
      'sidekiq.yml'
    ].freeze

    def initialize(host, appId, cluster, custom_config_file, opts = {})
      @host = host
      @appId = appId
      @cluster = cluster
      @custom_config_file = custom_config_file.present? ? [YAML.load(custom_config_file)].flatten : []
      @use_auth = opts[:use_auth]
    end

    def start
      p "[Apollo] auth: #{@use_auth} "
      p "[Apollo] start pulling configurations... \
        host: #{@host} \
        appId: #{@appId} \
        cluster: #{@cluster} \
        "

      if @appId.strip.empty?
        p '[Apollo] appId can not be nil'
        return
      end

      file_loop do |file|
        p "[Apollo] start pulling #{file} ..."
        result = response
        message = result['message']

        if message.blank?
          configurations = result['configurations']['content']
          release_key = result['releaseKey']
          write_yml(file, configurations, release_key)
        else
          p "[Apollo Center Return] #{message}"
        end
      end
    end

    def file_loop
      (CONFIG_FILE + @custom_config_file).uniq.each do |file|
        @url = url(file)
        yield(file)
      end
    end

    def write_yml(file, configs, release_key)
      if !configs || configs.strip.empty?
        p "[Apollo] Skip write #{file} with blank configs by release: #{release_key}"
        return
      end
      File.write("config/#{file}", configs)
      p "[Apollo] writed to local successfully with release: #{release_key}"
    end

    def response
      JSON.parse(Net::HTTP.get(uri))
    rescue Net::ReadTimeout, Net::OpenTimeout
      p '[Apollo] Application center can not connect now!'
    end

    def uri
      URI.parse(@url)
    end

    def url(file)
      "#{@host}/configs/#{@appId}/#{@cluster}/#{file}"
    end
  end
end
