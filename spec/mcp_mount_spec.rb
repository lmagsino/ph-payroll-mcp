# frozen_string_literal: true

# Protocol round-trips over the real middleware stack. Stateless Streamable HTTP
# answers each POST /mcp in-band, so rack-test can drive the whole exchange. Exact
# figures belong to the calculator specs; these only prove the payload survives the wire.
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

  it "lists all seven tools" do
    tools = rpc("tools/list")["result"]["tools"]

    expect(tools.map { |t| t["name"] }).to match_array(Tools::ALL.map(&:tool_name))
  end

  it "computes a payslip through tools/call, cited per source" do
    result = rpc("tools/call", { name: "compute_net_pay",
                                 arguments: { gross_monthly_salary: 30_000, member_type: "employed" } })["result"]
    payslip = JSON.parse(result["content"].first["text"])

    expect(result["isError"]).to be(false)
    expect(payslip["net_pay"]).to be_a(Numeric)
    expect(payslip["sources"].keys).to contain_exactly("sss", "philhealth", "pagibig", "withholding_tax")
  end

  it "rejects arguments outside the input schema as a tool error" do
    result = rpc("tools/call", { name: "compute_net_pay",
                                 arguments: { gross_monthly_salary: 30_000, member_type: "intern" } })["result"]

    expect(result["isError"]).to be(true)
    expect(result["content"].first["text"]).to match(/member_type/)
  end

  it "passes unknown paths through to the Sinatra app (404)" do
    get "/definitely-not-a-route"

    expect(last_response.status).to eq(404)
  end
end
