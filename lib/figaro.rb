require "figaro/error"
require "figaro/env"
require "figaro/application"
require 'figaro/apollo_portal'
require 'figaro/apollo_params'

module Figaro
  extend self
  attr_writer :adapter, :application, :apollo_config, :apollo_credential, :apollo_config_adapter, :apollo_credential_adapter

  def env
    Figaro::ENV
  end

  def adapter
    @adapter ||= Figaro::Application
  end

  def application
    @application ||= adapter.new
  end

  def apollo_config_adapter
    @apollo_config_adapter ||= Figaro::Application
  end

  def apollo_config
    @apollo_config ||= apollo_config_adapter.new
  end

  def apollo_credential_adapter
    @apollo_credential_adapter ||= Figaro::Application
  end

  def apollo_credential
    @apollo_credential ||= apollo_credential_adapter.new
  end

  def load
    begin
      # Initilize Apollo configuration
      apollo_config.load
      apollo_credential.load

      options = Figaro::ApolloParams.new.params

      if !options.values.include?(nil) &&
          ::ENV['SKIP_APOLLO'].blank?
        Figaro::ApolloPortal.new(**options).start
      end
    rescue => e
      puts "[Apollo] start error: #{e}"
    ensure
      application.load
    end
  end

  def require_keys(*keys)
    missing_keys = keys.flatten - ::ENV.keys
    raise MissingKeys.new(missing_keys) if missing_keys.any?
  end
end

require "figaro/rails"
