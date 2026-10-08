require "rails_helper"

RSpec.describe Bonds::ScheduleGenerator do
  def rows(par:, rate:, issued:, matures:)
    described_class.new(par_amount_cents: par, coupon_rate: rate, issued_on: issued, maturity_on: matures).rows
  end

  it "retires equal principal each year and charges interest on the declining balance" do
    schedule = rows(par: 1_000_000_00, rate: "0.04", issued: Date.new(2024, 7, 1), matures: Date.new(2029, 7, 1))

    expect(schedule.map(&:to_h)).to eq([
      { due_on: Date.new(2025, 7, 1), principal_cents: 200_000_00, interest_cents: 40_000_00 },
      { due_on: Date.new(2026, 7, 1), principal_cents: 200_000_00, interest_cents: 32_000_00 },
      { due_on: Date.new(2027, 7, 1), principal_cents: 200_000_00, interest_cents: 24_000_00 },
      { due_on: Date.new(2028, 7, 1), principal_cents: 200_000_00, interest_cents: 16_000_00 },
      { due_on: Date.new(2029, 7, 1), principal_cents: 200_000_00, interest_cents: 8_000_00 }
    ])
  end

  it "puts the rounding remainder on the final payment so principal sums exactly to par" do
    schedule = rows(par: 100_00 + 1, rate: "0.05", issued: Date.new(2024, 1, 1), matures: Date.new(2027, 1, 1))

    expect(schedule.map(&:principal_cents)).to eq([3333, 3333, 3335])
    expect(schedule.sum(&:principal_cents)).to eq(10_001)
  end

  it "ends on the maturity date when maturity is not an exact anniversary" do
    schedule = rows(par: 300_00, rate: "0.03", issued: Date.new(2024, 3, 15), matures: Date.new(2026, 9, 1))

    expect(schedule.map(&:due_on)).to eq([Date.new(2025, 3, 15), Date.new(2026, 3, 15), Date.new(2026, 9, 1)])
  end
end
