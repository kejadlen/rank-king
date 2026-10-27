# frozen_string_literal: true

require "roda"

require_relative "models"
require_relative "proxy_auth"
require_relative "sync"
require_relative "views/home"
require_relative "views/list/show"

module RankKing
  class Web < Roda
    plugin :halt
    plugin :static, %w[ /css /favicon.svg ]
    plugin :sessions, secret: CONFIG.session_secret
    plugin :route_csrf, csrf_failure: :empty_403, check_request_methods: %w[POST]
    plugin :error_handler, classes: [ProxyAuth::MissingLogin] do |e|
      response.status = 401
      response["Content-Type"] = "text/plain"
      "Unauthorized: #{e.message}.\n"
    end

    route do |r|
      check_csrf!
      user = User.find_or_create(login: ProxyAuth.login(r.env))

      r.root do
        lists = user.lists_dataset.order(:id).all
        Views::Home.new(lists: lists, csrf: method(:csrf_token)).call
      end

      r.on "lists" do
        r.is do
          r.post do
            name = r.params["name"].to_s.strip
            r.halt 422 if name.empty?

            entries = Sources::Text.new.entries(r.params["items"])
            r.halt 422 if entries.size < 2

            axes_text = r.params["axes"].to_s.strip
            axis_names = axes_text.lines.map(&:strip).reject(&:empty?)

            list = DB.transaction do
              l = List.create(name: name, user_id: user.id, source_kind: Sources::Text.kind)
              Sync.call(l, entries)
              axis_names.each { |n| Axis.create(list_id: l.id, name: n) }
              l
            end

            r.redirect "/lists/#{list.id}"
          end
        end

        r.on Integer do |list_id|
          # Lists are private to their owner.
          list = user.lists_dataset.where(id: list_id).first
          r.halt 404 unless list

          r.is do
            r.get do
              Views::ListViews::Show.new(list: list, csrf: method(:csrf_token)).call
            end
          end

          r.on "sync" do
            r.post do
              Sync.call(@list, @list.source.entries(r.params["snapshot"]))

              r.redirect "/lists/#{@list.id}"
            end
          end

          r.on "results" do
            r.post do
              axis_id = r.params["axis_id"].to_i
              winner_id = r.params["winner_id"].to_i
              loser_id = r.params["loser_id"].to_i

              axis = list.axes_dataset.where(id: axis_id).first
              r.halt 422 unless axis

              winner = list.items_dataset.where(id: winner_id).first
              loser = list.items_dataset.where(id: loser_id).first
              r.halt 422 unless winner && loser
              r.halt 422 if winner.id == loser.id

              Result.create(axis_id: axis.id, winner_id: winner.id, loser_id: loser.id)

              r.redirect "/lists/#{list.id}"
            end
          end
        end
      end
    end
  end
end
