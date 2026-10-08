module Api
  class DashboardsController < BaseController
    DEFAULT_WINDOW_DAYS = 90

    def show
      days = params.fetch(:days, DEFAULT_WINDOW_DAYS).to_i.clamp(1, 3650)
      upcoming = DebtServicePayment.due_within(days).includes(bond: :issuer).order(:due_on)
      outstanding = Issuer.outstanding_principal_cents_by_issuer

      render json: {
        window_days: days,
        upcoming_payments: upcoming.map { |payment| PaymentSerializer.upcoming(payment) },
        issuers: Issuer.order(:name).map { |issuer| IssuerSerializer.summary(issuer, outstanding_principal_cents: outstanding.fetch(issuer.id, 0)) }
      }
    end
  end
end
