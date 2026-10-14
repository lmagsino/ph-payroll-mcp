# frozen_string_literal: true

require "rack/cors"
require "mcp"
require_relative "app"
require_relative "app/payroll"
require_relative "app/mcp/tools"

# Fail fast at boot if any rate table is malformed (missing citation, bad shape).
# Same validation runs in CI via bin/validate_tables.
Payroll::RateTables.load!

# Cross-origin: MCP clients (Claude/ChatGPT connectors, IDEs) call from other origins.
# Public read-only compute API, no auth — allow all origins (see README disclaimer).
use Rack::Cors do
  allow do
    origins "*"
    resource "*", headers: :any, methods: %i[get post delete options]
  end
end

version = File.read(File.expand_path("VERSION", __dir__)).strip

server = MCP::Server.new(name: "ph-payroll-mcp", version: version, tools: Tools::ALL)

# stateless: every POST /mcp is self-contained and nothing is kept between requests,
# so Puma's worker count never matters. Flip to stateful only if a client insists on
# Mcp-Session-Id, and then run Puma with `workers 0`.
#
# enable_json_response: answers each request with one JSON body instead of an SSE
# stream. No tool streams progress or calls back to the client, so SSE buys nothing.
#
# dns_rebinding_protection: false — the gem's default only accepts loopback Host
# headers, which would reject the public Render hostname. Rebinding guards a local
# server's private data; this one exposes read-only public-reference math, so the
# check protects nothing. Turn it back on (with allowed_hosts:) if auth is ever added.
transport = MCP::Server::Transports::StreamableHTTPTransport.new(
  server,
  stateless: true,
  enable_json_response: true,
  dns_rebinding_protection: false
)

map("/mcp") { run transport }
run PhPayrollMcp
