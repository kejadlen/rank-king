# frozen_string_literal: true

ENV["DATABASE_URL"] = ":memory:"
# The Google client the app requires. No request reaches Google: the
# YouTube tests' app subclass hands out a fake one.
ENV["GOOGLE_CLIENT_ID"] = "client-id"
ENV["GOOGLE_CLIENT_SECRET"] = "client-secret"
