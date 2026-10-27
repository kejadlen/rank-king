# frozen_string_literal: true

ENV["DATABASE_URL"] = ":memory:"
# A Google client, so the YouTube routes are on; no request leaves the
# tests, which swap RankKing::Google.transport for canned answers.
ENV["GOOGLE_CLIENT_ID"] = "client-id"
ENV["GOOGLE_CLIENT_SECRET"] = "client-secret"
