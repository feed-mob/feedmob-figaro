Simple, Heroku-friendly Rails app configuration using `ENV` and a single YAML file

### Figaro for [Apollo](https://github.com/ctripcorp/apollo)

Apollo is a applicaiton configuration center. When we hanve many sub-portal and
want to unified management all `config/application.yml`. This Gem result from the
idea.

### Getting Started

Add Figaro to your Gemfile and `bundle install`:

```ruby
gem 'figaro', git: "https://github.com/feed-mob/feedmob-figaro", branch: 'master'
```

### Using exclude development

It load ```apollo.yml``` to config apollo configuration center.

example:

```
APOLLO_CLUSTER: default
APOLLO_APP_ID: feedmob-XXX
APOLLO_HOST: http://localhost:8080
APOLLO_CUSTOM_CONFIG_FILE: ''

 stage:
  APOLLO_HOST: http://xxx.com:8080

 production:
  APOLLO_HOST: http://xxx.com:8080

```

If Apollo has configured, after this will overwrite local `config/application.yml` and `config/sidekiq.yml`

### Tip
- This Gem start when rails before configuration,
- If you single start sidekiq, Please start rails server first.
- Add prefix `SKIP_APOLLO=true` to the command If you want to run a command on stage/production environment without downloading apollo configurations

### Using in development

Just see the [doc](https://github.com/laserlemon/figaro) from the official.

### Modern Ruby / Rails compatibility (1.2.0)

The fork allows Thor 0.x and 1.x, Bundler 1.x through 4.x, and declares its
JSON/Net::HTTP dependencies explicitly. The modern CI matrix covers Ruby 2.7
with Rails 6.1, Ruby 3.2 with Rails 7.2, and Ruby 3.4 / 4.0 with Rails 8.1.
Older Rails gemfiles remain available for historical use; they are not part of
the modern CI matrix. This is a Git-sourced fork; the gem name remains `figaro`.

`figaro install` supports current Ruby file APIs, and `figaro heroku:set` uses
Bundler's unbundled environment API when available, retaining the older fallback.
Configuration files remain **trusted application code**: ERB executes, and YAML
aliases and legacy types retain their original semantics under Psych 4+.
Do not load config supplied by untrusted users.

Apollo behavior is unchanged:

- Existing process environment variables take precedence over downloaded values.
- Only `stage` / `production` fetch remote config. Development uses local files.
- Set `SKIP_APOLLO=true` during image builds, asset precompilation and offline
  commands to avoid contacting Apollo. This still loads local `application.yml`.
- Both web and job processes need the same Apollo configuration at startup.
- `application.yml` and `sidekiq.yml` remain the default namespaces, plus any
  `APOLLO_CUSTOM_CONFIG_FILE` entries. Apps using Solid Queue do not need to use
  the downloaded Sidekiq file.
- This release does not add live config refresh, change outage handling, or
  switch an application's existing CI/Kamal variables to Apollo automatically.

Run the modern checks with the selected rbenv Ruby (no real Apollo, Heroku,
database, or application credentials are needed):

```sh
export BUNDLE_GEMFILE=gemfiles/modern.gemfile
export RAILS_VERSION='~> 8.1.0'
rbenv exec bundle install
rbenv exec bundle exec ruby script/check_compatibility.rb
rbenv exec bundle exec rspec --options /dev/null --require ./spec/modern_helper.rb \
  spec/figaro_spec.rb spec/figaro/application_spec.rb spec/figaro/env_spec.rb \
  spec/figaro/rails/application_spec.rb spec/figaro/apollo_client_spec.rb
```

The integration check boots temporary Rails apps, makes an HTTP request through
the Rails stack, pulls synthetic config from a loopback Apollo server, and runs
the CLI with a local Heroku stub. It writes a repeatable JSON report to ignored
`tmp/compatibility.json`. CI uploads this and the existing core-spec report.
Use a fresh lockfile when changing Ruby / Rails combinations; modern lockfiles
under `gemfiles/` are ignored.
