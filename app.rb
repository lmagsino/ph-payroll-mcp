# frozen_string_literal: true

require "sinatra/base"

# Thin HTTP app that lives alongside the MCP transport.
#
#   request ──▶ Rack::Cors ──┬─ /mcp  → MCP Streamable HTTP transport (config.ru)
#                             └─ else  → this Sinatra app
#
# It only serves /health (liveness probe + keep-alive target).
class PhPayrollMcp < Sinatra::Base
  set :host_authorization, permitted_hosts: [] # public API: any Host, same as the /mcp transport

  get "/health" do
    content_type :text
    "ok"
  end
end
