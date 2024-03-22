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

  def apollo_can_blank_config
    [:credentails, :label]
  end

  def load
    begin
      # Initilize Apollo configuration
      apollo_config.load
      apollo_credential.load

      options = Figaro::ApolloParams.new.params
      valid_options = options.reject{|key| apollo_can_blank_config.include?(key) }
      if !valid_options.values.include?(nil) && ::ENV['SKIP_APOLLO'].blank?
        Figaro::ApolloPortal.new(**options).start
      else
        puts "[Apollo] config error: config include nil value, will not load config from Apollo"
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
