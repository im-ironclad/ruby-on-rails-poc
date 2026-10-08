# Mirrors app/frontend/types/bonds.ts (Payment, UpcomingPayment).
class PaymentSerializer
  def self.call(payment)
    {
      id: payment.id,
      bond_id: payment.bond_id,
      due_on: payment.due_on.iso8601,
      principal_cents: payment.principal_cents,
      interest_cents: payment.interest_cents,
      total_cents: payment.total_cents,
      paid_on: payment.paid_on&.iso8601,
      status: payment.status
    }
  end

  # Expects bond and bond.issuer preloaded (see Api::DashboardsController#show).
  def self.upcoming(payment)
    call(payment).merge(
      bond_series_name: payment.bond.series_name,
      cusip: payment.bond.cusip,
      issuer_id: payment.bond.issuer_id,
      issuer_name: payment.bond.issuer.name
    )
  end
end
