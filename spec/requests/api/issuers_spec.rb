require "rails_helper"

RSpec.describe "Issuers API", type: :request do
  describe "GET /api/issuers/:id" do
    it "returns the issuer with each bond and its schedule" do
      issuer = create(:issuer, name: "Multnomah County", issuer_type: "county")
      bond = Bonds::Create.call(attributes_for(:bond, issuer_id: issuer.id, issued_on: Date.new(2024, 1, 1), maturity_on: Date.new(2026, 1, 1)))

      get "/api/issuers/#{issuer.id}"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to include("name" => "Multnomah County", "issuer_type" => "county")
      expect(body["bonds"].sole).to include("cusip" => bond.cusip, "coupon_rate" => "0.04", "outstanding_principal_cents" => 5_000_000_00)
      expect(body["bonds"].sole["payments"].map { |p| p["due_on"] }).to eq(%w[2025-01-01 2026-01-01])
    end

    # The N+1 guard. Serializing bonds -> payments without preloading costs one query per bond.
    # With includes(bonds: :debt_service_payments) the count is flat: issuer, bonds, payments.
    it "runs the same number of queries for 1 bond as for 5 bonds" do
      issuer = create(:issuer)
      Bonds::Create.call(attributes_for(:bond, issuer_id: issuer.id))
      one_bond = count_queries { get "/api/issuers/#{issuer.id}" }

      4.times { Bonds::Create.call(attributes_for(:bond, issuer_id: issuer.id)) }
      five_bonds = count_queries { get "/api/issuers/#{issuer.id}" }

      expect(response.parsed_body["bonds"].size).to eq(5)
      expect(five_bonds).to eq(one_bond)
      expect(five_bonds).to eq(3)
    end

    it "returns 404 with an error body for an unknown issuer" do
      get "/api/issuers/0"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq("errors" => { "base" => ["Issuer not found"] })
    end
  end
end
