FactoryBot.define do
  factory :issuer do
    sequence(:name) { |n| "City of Springfield #{n}" }
    issuer_type { "city" }
    state { "OR" }
  end

  factory :bond do
    issuer
    series_name { "General Obligation Bonds, Series 2024A" }
    sequence(:cusip) { |n| format("123456%03d", n) }
    par_amount_cents { 5_000_000_00 }
    coupon_rate { "0.04" }
    issued_on { Date.new(2024, 7, 1) }
    maturity_on { Date.new(2034, 7, 1) }
  end

  factory :debt_service_payment do
    bond
    sequence(:due_on) { |n| Date.new(2025, 7, 1) + n.days }
    principal_cents { 100_000_00 }
    interest_cents { 10_000_00 }
  end
end
