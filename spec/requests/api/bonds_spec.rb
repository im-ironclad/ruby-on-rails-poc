require "rails_helper"

RSpec.describe "Bonds API", type: :request do
  let(:issuer) { create(:issuer) }
  let(:valid_params) do
    {
      bond: {
        issuer_id: issuer.id, series_name: "Sewer Revenue Bonds, Series 2026", cusip: "55555ZZ12",
        par_amount_cents: 1_200_000_00, coupon_rate: "0.0475",
        issued_on: "2026-01-15", maturity_on: "2030-01-15"
      }
    }
  end

  describe "POST /api/bonds" do
    it "creates the bond and returns its generated schedule" do
      post "/api/bonds", params: valid_params, as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body).to include("cusip" => "55555ZZ12", "coupon_rate" => "0.0475", "par_amount_cents" => 1_200_000_00)
      expect(body["payments"].map { |p| [p["due_on"], p["principal_cents"], p["interest_cents"]] }).to eq([
        ["2027-01-15", 300_000_00, 57_000_00],
        ["2028-01-15", 300_000_00, 42_750_00],
        ["2029-01-15", 300_000_00, 28_500_00],
        ["2030-01-15", 300_000_00, 14_250_00]
      ])
      expect(Bond.find(body["id"]).debt_service_payments.count).to eq(4)
    end

    it "returns field errors and writes nothing when validation fails" do
      create(:bond, cusip: "55555ZZ12")
      params = valid_params.deep_merge(bond: { maturity_on: "2025-01-01", par_amount_cents: 0 })

      expect { post "/api/bonds", params:, as: :json }.not_to change(DebtServicePayment, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include(
        "cusip" => ["has already been taken"],
        "par_amount_cents" => ["must be greater than 0"],
        "maturity_on" => ["must be after the issue date"]
      )
    end

    it "ignores attributes outside the permitted list" do
      post "/api/bonds", params: valid_params.deep_merge(bond: { id: 999_999, created_at: "1999-01-01" }), as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["id"]).not_to eq(999_999)
    end

    # Form-encoded on purpose. For JSON bodies, Rails' ParamsWrapper copies top-level keys under "bond"
    # automatically (on by default via config.action_controller.wrap_parameters_by_default), so the key is never missing.
    it "returns 400 when the bond key is missing" do
      post "/api/bonds", params: { cusip: "X" }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq("errors" => { "bond" => ["is required"] })
    end
  end
end
