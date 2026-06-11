WebAuthn.configure do |config|
  # Must match the browser's window.location.origin exactly (scheme + host + port).
  # localhost is a secure context, so dev works without TLS. Override per environment.
  config.allowed_origins = [ ENV.fetch("WEBAUTHN_ORIGIN") { "http://localhost:#{ENV.fetch("PORT", 3000)}" } ]

  # Relying Party name shown in the authenticator's UI. rp_id defaults to the
  # origin's host (e.g. "localhost"), which is what we want.
  config.rp_name = "Authentication Hell"
end
