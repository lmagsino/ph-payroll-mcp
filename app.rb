# frozen_string_literal: true

require "sinatra/base"

# Thin HTTP app that lives alongside the MCP transport.
#
#   request ──▶ Rack::Cors ──▶ FastMcp transport ──┬─ /mcp/*  → MCP (JSON-RPC/SSE)
#                                                    └─ else    → this Sinatra app
#
# For now it only serves /health (liveness probe + keep-alive target). MCP tools
# are registered on the FastMcp server in config.ru during later milestones.
class PhPayrollMcp < Sinatra::Base
  set :host_authorization, permitted_hosts: [] # public API; hosts handled by CORS + transport

  get "/health" do
    content_type :text
    "ok"
  end
end
