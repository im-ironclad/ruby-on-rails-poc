require "rails_helper"

RSpec.describe Bonds::Create do
  let(:issuer) { create(:issuer) }
  let(:attributes) do
    {
      issuer_id: issuer.id, series_name: "Water Revenue Bonds, Series 2025", cusip: "987654AB1",
      par_amount_cents: 3_000_000_00, coupon_rate: "0.035",
      issued_on: Date.new(2025, 1, 1), maturity_on: Date.new(2028, 1, 1)
    }
  end

  it "persists the bond with its full schedule" do
    bond = described_class.call(attributes)

    expect(bond).to be_persisted
    expect(bond.debt_service_payments.reload.map(&:due_on)).to eq([Date.new(2026, 1, 1), Date.new(2027, 1, 1), Date.new(2028, 1, 1)])
    expect(bond.debt_service_payments.sum(:principal_cents)).to eq(3_000_000_00)
  end

  it "rolls back the bond when a schedule row fails to save" do
    bad_row = Bonds::ScheduleGenerator::Row.new(due_on: Date.new(2026, 1, 1), principal_cents: -1, interest_cents: 0)
    allow_any_instance_of(Bonds::ScheduleGenerator).to receive(:rows).and_return([bad_row])

    expect { described_class.call(attributes) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(Bond.count).to eq(0)
    expect(DebtServicePayment.count).to eq(0)
  end

  it "raises on invalid bond attributes and writes nothing" do
    expect { described_class.call(attributes.merge(maturity_on: Date.new(2024, 1, 1))) }
      .to raise_error(ActiveRecord::RecordInvalid, /Maturity on must be after the issue date/)
    expect(Bond.count).to eq(0)
  end
end
