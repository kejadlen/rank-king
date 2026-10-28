# frozen_string_literal: true

ENV["DATABASE_URL"] = ":memory:"
# A Google client, so the YouTube routes are on; no request leaves the
# tests, which set RankKing::Google.default to a fake that answers itself.
ENV["GOOGLE_CLIENT_ID"] = "client-id"
ENV["GOOGLE_CLIENT_SECRET"] = "client-secret"
