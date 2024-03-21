require 'base64'
require 'openssl'

module Figaro
  class ApolloSignature
    class << self
      #
      # return {'Authorization' => "Apollo #{appId}:#{token}", Timestamp => millisecond }
      #
      def build_http_headers(url, appId, secret)
        ts = Time.now.strftime('%s%L')
        token = signature(ts, url, secret)
        headers = {}
        headers['Authorization'] = "Apollo #{appId}:#{token}"
        headers['Timestamp'] = ts
        headers
      end

      def signature(timestamp, url, secret)
        string_to_sign = "#{timestamp}\n#{url}"
        hmac_code = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha1'), secret, string_to_sign)
        Base64.encode64(hmac_code).strip
      end
    end
  end
end