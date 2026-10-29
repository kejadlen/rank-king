# frozen_string_literal: true

require "phlex"

module RankKing
  module Views
    module Sources
      # Where a youtube.com cookie is pasted, on the new-list form and in
      # the sync dialog. rank-king keeps it only for the one fetch.
      class YouTubeCookie < Phlex::HTML
        def view_template
          label(class: "field") do
            plain "YouTube cookie"
            textarea(name: "cookie", rows: 3, required: true, autocomplete: "off", spellcheck: "false")
            small { "The Cookie request header from a signed-in youtube.com tab, copied from your browser's developer tools. It is used for this fetch and not kept." }
          end
        end
      end

      # The YouTube playlist source's fields on the new-list form: a cookie,
      # then a choice of the playlists it opens, which app.js fetches into
      # [data-playlists] once the cookie is pasted.
      class YouTubeFields < Phlex::HTML
        def initialize(csrf:)
          @csrf = csrf
        end

        def view_template
          path = RankKing::Sources::YouTube::PLAYLISTS_PATH
          render YouTubeCookie.new
          div(data_playlists: path, data_csrf: @csrf.call(path)) do
            render YouTubePlaylists.new(playlists: nil)
          end
        end
      end

      # The choice of playlists, or why there is none yet. playlists is nil
      # until a cookie is pasted.
      class YouTubePlaylists < Phlex::HTML
        def initialize(playlists:, error: nil)
          @playlists = playlists
          @error = error
        end

        def view_template
          if @error
            p { "YouTube would not list your playlists: #{@error}" }
          elsif @playlists.nil?
            p { "Paste a cookie to choose one of your playlists." }
          elsif @playlists.empty?
            p { "Your YouTube account has no playlists yet." }
          else
            label(class: "field") do
              plain "Playlist"
              select(name: "playlist", required: true) do
                @playlists.each do |id, title|
                  option(value: id) { title }
                end
              end
              small { "Watch Later and private playlists are listed too." }
            end
          end
        end
      end

      # The YouTube playlist source's sync dialog: a fresh cookie to fetch
      # with, and what syncing does, shown working.
      class YouTube < Phlex::HTML
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
            render YouTubeCookie.new
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
