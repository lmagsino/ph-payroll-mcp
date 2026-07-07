# frozen_string_literal: true

source "https://rubygems.org"

ruby "3.3.11"

gem "fast-mcp"      # MCP server; exact version pinned in Gemfile.lock (Layer 2 dep, expect churn)
gem "puma"          # app server (dev + Render)
gem "rack-cors"     # MCP clients call cross-origin
gem "rackup"        # Rack 3 CLI
gem "sinatra"       # thin app for /health alongside the MCP middleware

group :development, :test do
  gem "dotenv"
  gem "rack-test"
  gem "rspec"
end
