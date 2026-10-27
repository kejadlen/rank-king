# frozen_string_literal: true

require "digest"
require "pathname"
require "phlex"

module RankKing
  module Views
    class Layout < Phlex::HTML
      STYLESHEETS = %w[
        /vendor/gloss/tokens.css
        /vendor/gloss/base.css
        /vendor/gloss/components.css
        /css/app.css
      ].freeze

      SCRIPTS = %w[
        /vendor/gloss/system.js
        /js/app.js
      ].freeze

      ASSET_VERSIONS = begin
        root = Pathname(__dir__).join("../../../public").expand_path
        (STYLESHEETS + SCRIPTS).to_h {|path|
          # Pathname#join would treat the leading slash as a new root.
          file = root.join(path.delete_prefix("/"))
          [path, file.exist? ? Digest::MD5.file(file).hexdigest[0, 10] : "0"]
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
            STYLESHEETS.each { |path| link(rel: "stylesheet", href: asset_path(path)) }
            SCRIPTS.each { |path| script(src: asset_path(path), defer: true) }
          end
          body do
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

    # The one row at the top of every screen: an optional way back, the
    # title, and whatever the screen puts at the far end.
    class PageHeader < Phlex::HTML
      def initialize(title:, back: nil, back_label: nil, size: "type-h3")
        @title = title
        @back = back
        @back_label = back_label
        @size = size
      end

      def view_template(&block)
        header do
          if @back
            a(href: @back, class: "icon-button", data_size: "lg", aria_label: @back_label,
              style: "--gl-icon: var(--gl-icon-chevron-left)")
          end
          h1(class: @size) { @title }
          yield if block
        end
      end
    end
  end
end
