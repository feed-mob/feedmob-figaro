require "figaro/application"
require 'figaro/apollo_portal'
require 'figaro/apollo_params'

module Figaro
  class CLI < Thor
    class ApolloPull
      attr_reader :options

      APOLLO_FIXED_PATH = {
        apollo_config: "config/apollo.yml",
        apollo_credential: "#{Dir.home}/.apollo/credentials"
      }.freeze

      def self.run(options = {})
        new(options).run
      end

      def initialize(options = {})
        @options = options
      end

      # First, read local file and load to ENV
      # Second, construct params for Apollo through ENV
      # Third, request Apollo and pull YML file to local
      def run
        begin
          load_apollo_fixed_config
          apollo_options = Figaro::ApolloParams.new.params
          valid_options = apollo_options.reject{|key| apollo_can_blank_config.include?(key) }

          if !valid_options.values.include?(nil) &&
              ::ENV['SKIP_APOLLO'].nil?
            Figaro::ApolloPortal.new(**apollo_options).start
          else
            puts "[Apollo] config error: config include nil value, will not load config from Apollo"
          end
        rescue => e
          puts "[Apollo] start error: #{e}"
        end
      end

      private

      def load_apollo_fixed_config
        APOLLO_FIXED_PATH.each do |k, v|
          Figaro::Application.new(path: v, environment: options[:environment]).load
        end
      end

      def apollo_can_blank_config
        [:credentails, :label]
      end
    end
  end
end
