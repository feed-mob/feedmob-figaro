require 'net/http'
require 'json'
require 'figaro/apollo_signature'

module Figaro
  class ApolloPortal
    INFO_PREFIX = '[Apollo] Application Center'.freeze

    # Params:
    # host: The target for Apollo
    # env: The ENV for files on Apollo
    # app_id: The Project name
    # cluster_name: The Apollo Cluster
    # namespace_names: Files on Apollo existed
    # secret_key: get secret from ENV by this key
    # label: label for gray deploy
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
      url = "/configs/#{@app_id}/#{@cluster_name}/#{file_name}"
      url = "#{url}?label=#{@label}" unless @label.nil?
      uri = URI.parse("#{@host}#{url}")

      secret ? query_by_signature(url, uri) : query_normal(uri)
    rescue Net::ReadTimeout, Net::OpenTimeout
      puts '[Apollo] Application Center can not connect now!'
    end

    def query_normal(uri)
      Net::HTTP.start(uri.host, uri.port,
        :use_ssl => uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new(uri)
        http.request(request)
      end
    end

    def query_by_signature(url, uri)
      headers = Figaro::ApolloSignature.build_http_headers(url, @app_id, secret)
      Net::HTTP.start(uri.host, uri.port,
        :use_ssl => uri.scheme == 'https') { |http|
        request = Net::HTTP::Get.new(uri)
        request['Authorization'] = headers['Authorization']
        request['Timestamp'] = headers['Timestamp']
        http.request(request)
      }
    end

    def secret
      ::ENV[@secret_key] || ::ENV[@app_id]
    end
  end
end
