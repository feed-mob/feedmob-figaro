module Figaro
  class ApolloParams
    attr_reader :params

    def initialize
      secret_key = "APOLLO_SECRET_#{appId}"
      label_key = "APOLLO_LABEL_#{appId}"
      host = ::ENV['APOLLO_HOST']
      apollo_env = ::ENV['APOLLO_ENV']
      appId = ::ENV['APOLLO_APP_ID']
      cluster = ::ENV['APOLLO_CLUSTER']
      namespaces = ::ENV['APOLLO_NAMESPACES']
      credentails = ::ENV[secret_key] || ::ENV[appId]
      label = ::ENV[label_key]

      @params = {
        host: host,
        env: apollo_env,
        app_id: appId,
        cluster_name: cluster,
        namespace_names: namespaces.split(',').map { |item| item.strip },
        credentails: credentails,
        label: label
      }
    end
  end
end
