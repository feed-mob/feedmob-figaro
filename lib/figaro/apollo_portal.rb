require 'net/http'

module Figaro
  class ApolloPortal
    INFO_PREFIX = '[Apollo] Application Center'.freeze

    # Params:
    # host: The target for Apollo
    # env: The ENV for files on Apollo
    # app_id: The Project name
    # cluster_name: The Apollo Cluster
    # namespace_names: Files on Apollo existed
    def initialize(options = {})
      options.each { |name, value| instance_variable_set("@#{name}", value) }
    end

    def start
      puts "[Apollo] start pulling ..."

      @namespace_names.each do |file_name|
        response = get_response(file_name)
        if response.code == '401'
          puts "#{INFO_PREFIX} Unauthorized!"
          return
        elsif response.code == '200' && response.body == ''
          puts "#{INFO_PREFIX} file name not exist on Apollo.
               Please Check config. Remove in apollo.yml
               OR Add it on Apollo Center"
          next
        end

        res_body = JSON.parse(response.body)
        if !res_body['message'].nil? && res_body['message'] != ''
          puts "#{INFO_PREFIX} Return: #{res_body['message']}"
          next
        end

        file_content = res_body['configurations']['content']
        write_yml(file_name, file_content, res_body['dataChangeLastModifiedTime'])
      end
    end

    def write_yml(file_name, file_content, timestamp)
      File.write("config/#{file_name}", file_content)
      puts "#{INFO_PREFIX} writed #{file_name} to local successfully with last modified time: #{timestamp}"
    end

    def get_response(file_name)
      url = "#{@host}/openapi/v1/envs/#{@env}/apps/#{@app_id}/clusters/#{@cluster_name}/namespaces/#{file_name}/releases/latest"
      uri = URI.parse(url)

      Net::HTTP.start(uri.host, uri.port,
        :use_ssl => uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new uri, "Authorization" => "#{@credentails}"

        http.request(request)
      end
    rescue Net::ReadTimeout, Net::OpenTimeout
      puts '[Apollo] Application Center can not connect now!'
    end
  end
end
