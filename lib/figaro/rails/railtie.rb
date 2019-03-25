require 'figaro/apollo_client'
require 'figaro/rails/apollo_config'

module Figaro
  module Rails
    class Railtie < ::Rails::Railtie
      config.before_configuration do
        begin
          # load apollo.yml
          ApolloConfig.new.load

          host = ::ENV['APOLLO_HOST']
          appId = ::ENV['APOLLO_APP_ID']
          cluster = ::ENV['APOLLO_CLUSTER']

          if ::Rails.env.stage? || ::Rails.env.production?
            Figaro::ApolloClient.new(host, appId, cluster).start
          end
        rescue => e
          p "[Apollo] start error: #{e}"
        ensure
          Figaro.load
        end
      end
    end
  end
end
