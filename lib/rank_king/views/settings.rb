# frozen_string_literal: true

require "phlex"

require_relative "layout"

module RankKing
  module Views
    # The user's own settings, as against a list's. A future setting is a
    # new section here.
    class Settings < Phlex::HTML
      def initialize(user:, google_configured:, csrf:)
        @user = user
        @google_configured = google_configured
        @csrf = csrf
      end

      def view_template
        render Layout.new(title: "Settings — Rank King") do
          render PageHeader.new(title: "Settings", back: "/", back_label: "Lists")

          section do
            h2(class: "type-label") { "Google" }
            if @user.google_account
              render_connected
            elsif @google_configured
              p { "Connect Google to make lists from your YouTube playlists, private ones included." }
              a(href: "/settings/google/connect", class: "btn", data_variant: "primary") { "Connect Google" }
            else
              p { "This server has no Google client set up. Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET to connect Google." }
            end
          end
        end
      end

      private

      def render_connected
        action = "/settings/google/disconnect"
        p { "Connected. Lists can sync from your YouTube playlists." }
        form(method: "post", action:, data_confirm: "Disconnect Google? YouTube lists will stop syncing.") do
          input(type: "hidden", name: "_csrf", value: @csrf.call(action))
          button(type: "submit", data_variant: "danger", data_size: "sm") { "Disconnect" }
        end
      end
    end
  end
end
