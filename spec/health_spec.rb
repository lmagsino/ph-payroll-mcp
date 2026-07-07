# frozen_string_literal: true

RSpec.describe "GET /health" do
  it "returns 200 with body 'ok'" do
    get "/health"

    expect(last_response.status).to eq(200)
    expect(last_response.body).to eq("ok")
  end
end
