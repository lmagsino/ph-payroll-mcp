# frozen_string_literal: true

# fast-mcp 1.6.0 returns a capitalized "Content-Type" response header. Rack 3
# requires lowercase header names, and its development-mode Rack::Lint raises
# "uppercase character in header name: Content-Type" — so a plain `rackup`
# 500s on /mcp routes in development.
#
# This middleware normalizes all response header names to lowercase so local
# development (and the MCP Inspector) works without forcing RACK_ENV=production.
# It is a no-op in effect for production (headers just get lowercased on the
# way out). Placed as the OUTERMOST app middleware so its output is what
# Rack::Lint inspects.
class NormalizeResponseHeaders
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    normalized = headers.each_with_object({}) { |(k, v), h| h[k.to_s.downcase] = v }
    [status, normalized, body]
  end
end
