# Mirrors app/frontend/types/bonds.ts (Bond, BondWithSchedule).
class BondSerializer
  def self.call(bond)
    {
      id: bond.id,
      issuer_id: bond.issuer_id,
      series_name: bond.series_name,
      cusip: bond.cusip,
      par_amount_cents: bond.par_amount_cents,
      # Decimal goes out as a string. A JSON number would round-trip through a float.
      coupon_rate: bond.coupon_rate.to_s("F"),
      issued_on: bond.issued_on.iso8601,
      maturity_on: bond.maturity_on.iso8601
    }
  end

  def self.with_schedule(bond)
    call(bond).merge(
      outstanding_principal_cents: bond.outstanding_principal_cents,
      payments: bond.debt_service_payments.map { |payment| PaymentSerializer.call(payment) }
    )
  end
end
