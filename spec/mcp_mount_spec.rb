# frozen_string_literal: true

# Verifies the fast-mcp transport is mounted at /mcp and scoped correctly.
# The HTTP+SSE transport delivers JSON-RPC results over the SSE channel, so we
# assert the mount claims its routes (status 200, not a Sinatra 404) rather than
# the full protocol round-trip — that lives in the M4 end-to-end test. We do NOT
# hit GET /mcp/sse here: it returns an open streaming body that would block
# rack-test. The SSE channel is covered by the M4 real-client test.
RSpec.describe "MCP transport mount" do
  it "intercepts POST /mcp/messages (transport claims the route)" do
    body = { jsonrpc: "2.0", id: 1, method: "tools/list", params: {} }.to_json
    post "/mcp/messages", body, "CONTENT_TYPE" => "application/json"

    expect(last_response.status).to eq(200)
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
