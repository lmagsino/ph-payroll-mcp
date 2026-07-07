# frozen_string_literal: true

require "logger"
require "rack/cors"
require "fast_mcp"
require_relative "app"
require_relative "lib/normalize_response_headers"

# Outermost: lowercase response header names so fast-mcp's capitalized
# "Content-Type" passes Rack 3's development-mode Lint (see the class comment).
use NormalizeResponseHeaders

# Cross-origin: MCP clients (Claude/ChatGPT connectors, IDEs) call from other origins.
# Public read-only compute API, no auth — allow all origins (see README disclaimer).
use Rack::Cors do
  allow do
    origins "*"
    resource "*", headers: :any, methods: %i[get post options]
  end
end

version = File.read(File.expand_path("VERSION", __dir__)).strip

# DEBUG in development, quiet (WARN) elsewhere so production and test logs stay clean.
log_level = ENV.fetch("RACK_ENV", "production") == "development" ? Logger::DEBUG : Logger::WARN
logger = Logger.new($stdout, level: log_level)

# Wrap the Sinatra app with the MCP transport. It intercepts /mcp/* and passes
# everything else through to Sinatra.
#
# localhost_only:false + allowed_origins:[/.*/] disables fast-mcp's DNS-rebinding
# protection, which otherwise (default localhost-only) rejects remote MCP clients.
# Acceptable here because the server is public by design and exposes only
# read-only public-reference math. Revisit if auth is ever added.
mcp = FastMcp.rack_middleware(
  PhPayrollMcp,
  name: "ph-payroll-mcp",
  version: version,
  logger: logger,
  localhost_only: false,
  allowed_origins: [/.*/]
) do |server|
  # Tools registered in later milestones (M3). None yet — tools/list returns [].
end

run mcp
