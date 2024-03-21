module Figaro
  class ApolloParams
    attr_reader :params

    def initialize
      host = ::ENV['APOLLO_HOST']
      apollo_env = ::ENV['APOLLO_ENV']
      appId = ::ENV['APOLLO_APP_ID']
      cluster = ::ENV['APOLLO_CLUSTER']
      namespaces = ::ENV['APOLLO_NAMESPACES']
      credentails = ::ENV[appId] || ::ENV['APOLLO_SECRET']

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
