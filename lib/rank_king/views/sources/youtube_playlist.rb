# frozen_string_literal: true

require "phlex"

module RankKing
  module Views
    module Sources
      # The YouTube playlist source's fields on the new-list form: a choice
      # of the user's playlists, once they have connected Google. playlists
      # is nil until then.
      class YouTubePlaylistFields < Phlex::HTML
        def initialize(playlists:, configured:, error: nil)
          @playlists = playlists
          @configured = configured
          @error = error
        end

        def view_template
          if @error
            p { "Google would not list your playlists: #{@error}" }
          elsif @playlists&.empty?
            p { "Your YouTube account has no playlists yet." }
          elsif @playlists
            label(class: "field") do
              plain "Playlist"
              select(name: "playlist", required: true) do
                @playlists.each do |id, title|
                  option(value: id) { title }
                end
              end
              small { "Private playlists are listed too. YouTube does not share Watch Later." }
            end
          elsif @configured
            p do
              plain "Connect Google in "
              a(href: "/settings") { "your settings" }
              plain " to make a list from a YouTube playlist."
            end
          else
            p { "This server has no Google client set up, so YouTube lists cannot be made yet." }
          end
        end
      end

      # The YouTube playlist source's sync dialog: there is nothing to
      # fill in, so it says what syncing does and shows it working.
      class YouTubePlaylist < Phlex::HTML
        def initialize(list:, csrf:)
          @list = list
          @csrf = csrf
        end

        def view_template
          action = "/lists/#{@list.id}/sync"

          header { "Sync from YouTube" }
          form(id: "sync-form", method: "post", action:, data_busy: "Syncing…") do
            input(type: "hidden", name: "_csrf", value: @csrf.call(action))
            p { "Fetches the playlist again. New videos are added, and videos that left it are hidden." }
            if (synced_at = @list.synced_at)
              small { "Last synced #{synced_at.strftime("%b %-d, %Y at %-I:%M %p")}." }
            end
          end
          footer do
            button(type: "button", commandfor: "sync-dialog", command: "close") { "Cancel" }
            button(type: "submit", form: "sync-form", data_variant: "primary") { "Sync" }
          end
        end
      end
    end
  end
end
