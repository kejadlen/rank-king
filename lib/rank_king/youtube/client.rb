# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module RankKing
  module YouTube
    # A minimal YouTube Data API v3 client authenticated with an OAuth access
    # token.
    class Client
      Error = Class.new(StandardError)

      BASE = "https://www.googleapis.com/youtube/v3/"

      def initialize(access_token:)
        @access_token = access_token
      end

      def get(path, params = {})
        uri = URI.join(BASE, path)
        uri.query = URI.encode_www_form(params)

        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{@access_token}"

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) {|http| http.request(request) }
        raise Error, "YouTube API #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      end
    end
  end
end
