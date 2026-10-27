# frozen_string_literal: true

require "roda"

require_relative "models"
require_relative "proxy_auth"
require_relative "views/home"
require_relative "views/list/new"
require_relative "views/list/show"
require_relative "views/list/compare"
require_relative "views/list/settings"

module RankKing
  class Web < Roda
    plugin :halt
    plugin :static, %w[ /css /js /vendor ]
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
        Views::Home.new(lists: lists).call
      end

      r.on "lists" do
        r.is do
          r.post do
            name = r.params["name"].to_s.strip
            r.halt 422 if name.empty?

            source_kind = r.params["source"] || "Text"
            r.halt 422 unless Sources::KINDS.include?(source_kind)

            items_text = r.params["items"].to_s.strip
            r.halt 422 if items_text.empty?

            item_names = items_text.lines.map(&:strip).reject(&:empty?)
            r.halt 422 if item_names.size < 2

            axis_names = names_param(r.params["axes"])

            list = DB.transaction do
              l = List.create(name: name, user_id: user.id, source_kind: source_kind)
              item_names.each { |n| Item.create(list_id: l.id, name: n) }
              axis_names.each { |n| Axis.create(list_id: l.id, name: n) }
              l
            end

            r.redirect "/lists/#{list.id}"
          end
        end

        r.get "new" do
          kinds = Sources::KINDS.to_h do |kind|
            [kind, Sources.fetch(kind).title] #: [String, String]
          end
          Views::ListViews::New.new(sources: kinds, csrf: method(:csrf_token)).call
        end

        r.on Integer do |list_id|
          # Lists are private to their owner.
          list = user.lists_dataset.where(id: list_id).first
          r.halt 404 unless list

          r.is do
            r.get do
              axis = list.axes_dataset.where(id: r.params["axis"].to_i).first
              Views::ListViews::Show.new(list: list, axis: axis, csrf: method(:csrf_token)).call
            end
          end

          r.is "settings" do
            r.get do
              source = Sources.fetch(list.source_kind).title
              Views::ListViews::Settings.new(list: list, source: source, csrf: method(:csrf_token)).call
            end

            r.post do
              name = r.params["name"].to_s.strip
              r.halt 422 if name.empty?

              kept = Array(r.params["axis_ids"]) #: Array[untyped]
              kept_ids = kept.map { |id| id.to_i }
              new_names = names_param(r.params["axes"])

              DB.transaction do
                list.update(name: name)
                list.axes_dataset.exclude(id: kept_ids).each { |axis| axis.destroy }
                new_names.each { |n| Axis.create(list_id: list.id, name: n) }
              end

              r.redirect "/lists/#{list.id}"
            end
          end

          # Submitted from the source's own sync dialog.
          r.post "sync" do
            list.source.sync(r.params)
            r.redirect "/lists/#{list.id}"
          end

          r.post "delete" do
            DB.transaction { list.destroy }
            r.redirect "/"
          end

          r.get "axes", Integer, "compare" do |axis_id|
            axis = list.axes_dataset.where(id: axis_id).first
            r.halt 404 unless axis

            Views::ListViews::Compare.new(list: list, axis: axis, csrf: method(:csrf_token)).call
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

              r.redirect "/lists/#{list.id}/axes/#{axis.id}/compare"
            end
          end
        end
      end
    end

    private

    # Names from a repeated field (`axes[]`), one per tag.
    #: (untyped) -> Array[String]
    def names_param(value)
      names = Array(value) #: Array[untyped]
      names.map { |n| n.to_s.strip }.reject(&:empty?).uniq
    end
  end
end
