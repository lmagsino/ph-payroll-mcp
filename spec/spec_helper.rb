# frozen_string_literal: true

require "rack"
require "rack/builder"
require "rack/test"
require "json"
require_relative "../app/payroll"

# Build the full production-shaped Rack app from config.ru (CORS + MCP transport
# + Sinatra), so specs exercise the real middleware stack, not a stub.
config_ru = File.expand_path("../config.ru", __dir__)
built = Rack::Builder.parse_file(config_ru)
OUTER_APP = built.is_a?(Array) ? built.first : built # Rack <3 returned [app, opts]

module RackAppHelper
  include Rack::Test::Methods

  def app
    OUTER_APP
  end
end

RSpec.configure do |config|
  config.include RackAppHelper

  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.order = :random
  config.disable_monkey_patching!
end
