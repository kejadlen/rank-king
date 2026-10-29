# frozen_string_literal: true

require "digest"
require "json"
require "net/http"
require "uri"

module RankKing
  # InnerTube, the API youtube.com's own pages call, signed in with the
  # user's browser cookie. It stands in for OAuth and the YouTube Data
  # API, which an Advanced Protection account cannot grant to an
  # unverified client and which never shares Watch Later. Every call goes
  # through #request, which a subclass overrides to answer without the
  # network, as the tests' does.
  class InnerTube
    # YouTube refused a request, or answered with something unexpected.
    class Error < StandardError; end

    # A video in a playlist, as YouTube describes it.
    # Signed in sig/rank_king/innertube.rbs: a Data class.
    # @rbs skip
    Video = Data.define(:id, :title, :channel_title, :thumbnail_url)

    ORIGIN = "https://www.youtube.com"
    BROWSE_URL = "#{ORIGIN}/youtubei/v1/browse?prettyPrint=false"
    # The web client InnerTube is told it is serving. YouTube may refuse
    # a version once it is old enough.
    CLIENT = { clientName: "WEB", clientVersion: "2.20261020.00.00", hl: "en", gl: "US" }.freeze
    # Each cookie a request is signed with, and the scheme its signature
    # goes under in the Authorization header.
    API_COOKIES = {
      "SAPISID" => "SAPISIDHASH",
      "__Secure-1PAPISID" => "SAPISID1PHASH",
      "__Secure-3PAPISID" => "SAPISID3PHASH",
    }.freeze #: Hash[String, String]

    # A Cookie header as pasted, without the "Cookie:" it may have been
    # copied with, or nil when it has no cookie to sign requests with.
    #: (String text) -> String?
    def self.cookie(text)
      cookie = text.strip.delete_prefix("Cookie:").strip.gsub(/\s*\n\s*/, " ")
      cookie if API_COOKIES.keys.any? { |name| jar(cookie)[name] }
    end

    #: (String cookie) -> Hash[String, String]
    def self.jar(cookie)
      jar = {} #: Hash[String, String]
      cookie.split(/;\s*/).each do |pair|
        name, value = pair.split("=", 2)
        jar[name.to_s] = value if value
      end
      jar
    end

    # Google's signature for a request made with a cookie: for each API
    # cookie, a SHA-1 of the time, its value, and the origin.
    #: (String cookie, ?at: Integer) -> String
    def self.authorization(cookie, at: Time.now.to_i)
      jar = jar(cookie)
      API_COOKIES.filter_map { |name, scheme|
        value = jar[name]
        "#{scheme} #{at}_#{Digest::SHA1.hexdigest("#{at} #{value} #{ORIGIN}")}" if value
      }.join(" ")
    end

    # The user's playlists, as [playlist id, title], in YouTube's order:
    # Watch Later and Liked videos among their own and the ones they saved.
    #: (String cookie) -> Array[[String, String]]
    def playlists(cookie)
      lockups = pages(cookie, { browseId: "FEplaylist_aggregation" }).flat_map { |page| find_all(page, "lockupViewModel") }
      lockups.filter_map { |lockup|
        next unless lockup["contentType"] == "LOCKUP_CONTENT_TYPE_PLAYLIST"

        title = lockup.dig("metadata", "lockupMetadataViewModel", "title", "content").to_s
        [lockup.fetch("contentId"), title] #: [String, String]
      }
    end

    # The videos in a playlist, in playlist order. Deleted videos, and
    # private ones the user cannot see, are not playable and are left out.
    # Some videos come with no channel.
    #: (String cookie, String playlist_id) -> Array[Video]
    def playlist_videos(cookie, playlist_id)
      renderers = pages(cookie, { browseId: "VL#{playlist_id}" }).flat_map { |page| find_all(page, "playlistVideoRenderer") }
      renderers.filter_map { |renderer|
        next unless renderer["isPlayable"]

        id = renderer.fetch("videoId")
        Video.new(
          id:,
          title: text(renderer["title"]).to_s,
          channel_title: text(renderer["shortBylineText"]),
          thumbnail_url: "https://i.ytimg.com/vi/#{id}/mqdefault.jpg",
        )
      }
    end

    private

    # Every page of a browse, following its continuations.
    #: (String cookie, Hash[Symbol, String] body) -> Array[Hash[String, untyped]]
    def pages(cookie, body)
      pages = [] #: Array[Hash[String, untyped]]
      loop do
        page = request(cookie, body)
        check(page) if pages.empty?
        pages << page

        token = find_all(page, "continuationItemRenderer")
          .flat_map { |item| find_all(item, "continuationCommand") }
          .first&.dig("token")
        break unless token

        body = { continuation: token }
      end
      pages
    end

    # A cookie YouTube has signed out still gets answers, as anyone would,
    # so a sync must not take them for an empty playlist.
    #: (Hash[String, untyped] page) -> void
    def check(page)
      params = page.dig("responseContext", "serviceTrackingParams").to_a.flat_map { |service| service["params"].to_a }
      unless params.any? { |param| param["key"] == "logged_in" && param["value"] == "1" }
        raise Error, "YouTube signed the cookie out. Paste a fresh one in settings."
      end

      alert = find_all(page, "alertRenderer").find { |a| a["type"] == "ERROR" }
      raise Error, text(alert["text"]) || "YouTube sent an error" if alert
    end

    # The words of an InnerTube text, which comes either whole or in runs.
    #: (untyped node) -> String?
    def text(node)
      return unless node.is_a?(Hash)

      node["simpleText"] || node["runs"]&.map { |run| run["text"] }&.join
    end

    # Every value under key, however deep: InnerTube nests the same
    # renderers differently from page to page.
    #: (untyped node, String key, ?Array[Hash[String, untyped]] found) -> Array[Hash[String, untyped]]
    def find_all(node, key, found = [])
      case node
      when Hash
        node.each { |k, v| k == key ? found << v : find_all(v, key, found) }
      when Array
        node.each { |v| find_all(v, key, found) }
      end
      found
    end

    # Makes one browse request and returns its JSON body.
    #: (String cookie, Hash[Symbol, String] body) -> Hash[String, untyped]
    def request(cookie, body)
      uri = URI(BROWSE_URL)
      post = Net::HTTP::Post.new(uri)
      post["Cookie"] = cookie
      post["Authorization"] = self.class.authorization(cookie)
      post["Origin"] = ORIGIN
      post["X-Origin"] = ORIGIN
      post["X-Goog-AuthUser"] = "0"
      post["Content-Type"] = "application/json"
      post.body = JSON.generate({ context: { client: CLIENT }, **body })

      response = Net::HTTP.start(uri.hostname.to_s, uri.port, use_ssl: true) { |http| http.request(post) }
      json = JSON.parse(response.body.to_s)
      return json if response.is_a?(Net::HTTPSuccess)

      raise Error, json.dig("error", "message") || "HTTP #{response.code}"
    rescue JSON::ParserError
      raise Error, "YouTube answered HTTP #{response&.code} with no JSON"
    end
  end
end
