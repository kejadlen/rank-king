# frozen_string_literal: true

require "roda"

require_relative "models"
require_relative "proxy_auth"
require_relative "innertube"
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
    plugin :error_handler, classes: [ProxyAuth::MissingLogin, InnerTube::Error] do |e|
      response["Content-Type"] = "text/plain"
      if e.is_a?(InnerTube::Error)
        response.status = 502
        "YouTube: #{e.message}\n"
      else
        response.status = 401
        "Unauthorized: #{e.message}.\n"
      end
    end

    route do |r|
      check_csrf!
      user = User.find_or_create(login: ProxyAuth.login(r.env))

      r.root do
        lists = user.lists_dataset.order(:id).all
        Views::Home.new(lists: lists).call
      end

      # A fragment for the new-list form: the playlists a pasted cookie
      # opens. It is a POST so the cookie stays out of URLs and logs.
      r.post "youtube", "playlists" do
        Sources::YouTube.playlists(r.params["cookie"], innertube:).call
      end

      r.on "lists" do
        r.is do
          r.post do
            name = r.params["name"].to_s.strip
            r.halt 422 if name.empty?

            source_kind = r.params["source"] || "Text"
            r.halt 422 unless Sources::KINDS.include?(source_kind)

            axis_names = names_param(r.params["axes"])

            # The source fills the list from its own fields, or turns it
            # down and nothing is made.
            list = DB.transaction {
              l = List.create(name: name, user_id: user.id, source_kind: source_kind)
              raise Sequel::Rollback unless Sources.fetch(source_kind).create(l, r.params, innertube:)

              axis_names.each do |n|
                Axis.create(list_id: l.id, name: n)
              end
              l
            }
            r.halt 422 unless list

            r.redirect "/lists/#{list.id}"
          end
        end

        r.get "new" do
          kinds = Sources::KINDS.map { |kind|
            source = Sources.fetch(kind)
            [kind, source.title, source.fields(csrf: method(:csrf_token))] #: [String, String, Sources::_Component]
          }
          Views::ListViews::New.new(sources: kinds, csrf: method(:csrf_token)).call
        end

        r.on Integer do |list_id|
          # Lists are private to their owner.
          list = user.lists_dataset.where(id: list_id).first
          r.halt 404 unless list

          r.is do
            r.get do
              axis = list.axes_dataset.where(id: r.params["axis"].to_i).first
              Views::ListViews::Show.new(list: list, source: source(list), axis: axis, csrf: method(:csrf_token)).call
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
            source(list).sync(r.params)
            r.redirect "/lists/#{list.id}"
          end

          r.post "delete" do
            DB.transaction { list.destroy }
            r.redirect "/"
          end

          r.post "axes" do
            name = r.params["name"].to_s.strip
            r.halt 422 if name.empty?

            axis = Axis.create(list_id: list.id, name: name)
            r.redirect "/lists/#{list.id}?axis=#{axis.id}"
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

    # The InnerTube client every route and source goes through. Tests
    # subclass the app to hand back a fake one.
    #: () -> InnerTube
    def innertube = InnerTube.new

    #: (List list) -> Sources::_Source
    def source(list) = Sources.fetch(list.source_kind).for(list, innertube:)

    # Names from a repeated field (`axes[]`), one per tag.
    #: (untyped) -> Array[String]
    def names_param(value)
      names = Array(value) #: Array[untyped]
      names.map { |n| n.to_s.strip }.reject(&:empty?).uniq
    end
  end
end
