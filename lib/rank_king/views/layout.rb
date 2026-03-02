# frozen_string_literal: true

require "digest"
require "phlex"

module RankKing
  module Views
    class Layout < Phlex::HTML
      ASSET_VERSIONS = begin
        root = File.expand_path("../../../public", __dir__)
        %w[
          /css/reset.css
          /css/utopia.css
          /css/app.css
        ].to_h {|path|
          file = File.join(root, path)
          [path, File.exist?(file) ? Digest::MD5.file(file).hexdigest[0, 10] : "0"]
        }.freeze
      end

      def initialize(title: "Rank King")
        @title = title
      end

      def view_template(&)
        doctype
        html(lang: "en") do
          head do
            meta(charset: "utf-8")
            meta(name: "viewport", content: "width=device-width, initial-scale=1")
            title { @title }
            link(rel: "stylesheet", href: asset_path("/css/reset.css"))
            link(rel: "stylesheet", href: asset_path("/css/utopia.css"))
            link(rel: "stylesheet", href: asset_path("/css/app.css"))
          end
          body do
            header(class: "site-header") do
              a(href: "/", class: "site-name") { "Rank King" }
            end
            main { yield }
          end
        end
      end

      private

      def asset_path(path)
        version = ASSET_VERSIONS[path]
        version ? "#{path}?v=#{version}" : path
      end
    end
  end
end
