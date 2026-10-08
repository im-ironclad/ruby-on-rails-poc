require "rails_helper"

RSpec.describe "Payments and dashboard API", type: :request do
  describe "PATCH /api/debt_service_payments/:id" do
    it "marks a payment paid, which flips its derived status" do
      payment = create(:debt_service_payment, due_on: Date.current + 10)

      patch "/api/debt_service_payments/#{payment.id}", params: { debt_service_payment: { paid_on: Date.current.iso8601 } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("status" => "paid", "paid_on" => Date.current.iso8601)
      expect(payment.reload.paid_on).to eq(Date.current)
    end

    it "does not let the client change amounts" do
      payment = create(:debt_service_payment, principal_cents: 100)

      patch "/api/debt_service_payments/#{payment.id}", params: { debt_service_payment: { paid_on: Date.current.iso8601, principal_cents: 1 } }, as: :json

      expect(payment.reload.principal_cents).to eq(100)
    end

    it "rejects a future paid_on" do
      payment = create(:debt_service_payment)

      patch "/api/debt_service_payments/#{payment.id}", params: { debt_service_payment: { paid_on: (Date.current + 1).iso8601 } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to eq("paid_on" => ["can't be in the future"])
      expect(payment.reload.paid_on).to be_nil
    end
  end

  describe "GET /api/dashboard" do
    it "lists unpaid payments due within the window and outstanding principal per issuer" do
      issuer = create(:issuer, name: "Salem")
      bond = create(:bond, issuer:)
      due_soon = create(:debt_service_payment, bond:, due_on: Date.current + 5, principal_cents: 700)
      create(:debt_service_payment, bond:, due_on: Date.current + 200, principal_cents: 300)
      create(:debt_service_payment, bond:, due_on: Date.current - 400, principal_cents: 999, paid_on: Date.current - 400)
      create(:issuer, name: "Zero Debt Town")

      get "/api/dashboard", params: { days: 30 }

      body = response.parsed_body
      expect(body["upcoming_payments"].map { |p| p["id"] }).to eq([due_soon.id])
      expect(body["upcoming_payments"].sole).to include("issuer_name" => "Salem", "status" => "upcoming")
      expect(body["issuers"].map { |i| [i["name"], i["outstanding_principal_cents"]] }).to eq([["Salem", 1000], ["Zero Debt Town", 0]])
    end

    it "does not issue a query per upcoming payment" do
      bond = create(:bond)
      create(:debt_service_payment, bond:, due_on: Date.current + 1)
      one = count_queries { get "/api/dashboard" }

      3.times { |i| create(:debt_service_payment, bond: create(:bond), due_on: Date.current + 2 + i) }
      four = count_queries { get "/api/dashboard" }

      expect(response.parsed_body["upcoming_payments"].size).to eq(4)
      expect(four).to eq(one)
    end
  end
end
