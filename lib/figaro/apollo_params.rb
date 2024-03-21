module Figaro
  class ApolloParams
    attr_reader :params

    def initialize
      # host = ::ENV['APOLLO_HOST']
      # apollo_env = ::ENV['APOLLO_ENV']
      # appId = ::ENV['APOLLO_APP_ID']
      # cluster = ::ENV['APOLLO_CLUSTER']
      # namespaces = ::ENV['APOLLO_NAMESPACES']
      # credentails = ::ENV[appId] || ::ENV['APOLLO_SECRET']

      host = 'http://s-config.feedmob.internal'
      apollo_env = ::ENV['APOLLO_ENV']
      appId = 'stage-chintest'
      cluster = 'default'
      namespaces = 'application.yml'
      credentails = 'df07a81fb56146a093d54553b74a3817'

      @params = {
        host: host,
        env: apollo_env,
        app_id: appId,
        cluster_name: cluster,
        namespace_names: namespaces.split(',').map { |item| item.strip },
        credentails: credentails
      }
    end
  end
end
