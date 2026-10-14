# frozen_string_literal: true

# Protocol round-trips over the real middleware stack. Stateless Streamable HTTP
# answers each POST /mcp in-band, so rack-test can drive the whole exchange.
RSpec.describe "MCP transport mount" do
  def rpc(method, params = {}, id: 1)
    post "/mcp", { jsonrpc: "2.0", id: id, method: method, params: params }.to_json,
         { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json, text/event-stream" }
    JSON.parse(last_response.body)
  end

  it "answers initialize with the server name and VERSION" do
    result = rpc("initialize",
                 { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "spec", version: "1" } })["result"]

    expect(result["serverInfo"]).to include("name" => "ph-payroll-mcp",
                                            "version" => File.read(File.expand_path("../VERSION", __dir__)).strip)
  end

  it "passes unknown paths through to the Sinatra app (404)" do
    get "/definitely-not-a-route"

    expect(last_response.status).to eq(404)
  end

  it "normalizes response header names to lowercase (Rack 3 compliance)" do
    get "/health"

    keys = last_response.headers.keys
    expect(keys).to eq(keys.map(&:downcase))
  end
end
