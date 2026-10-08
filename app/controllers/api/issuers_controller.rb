module Api
  class IssuersController < BaseController
    def index
      render json: Issuer.order(:name).map { |issuer| IssuerSerializer.base(issuer) }
    end

    def show
      # Without includes: 1 query for the issuer, 1 for its bonds, then 1 per bond for payments (N+1).
      # With includes: 3 queries total, no matter how many bonds. See spec/requests/api/issuers_spec.rb.
      issuer = Issuer.includes(bonds: :debt_service_payments).find(params[:id])
      render json: IssuerSerializer.detail(issuer)
    end
  end
end
