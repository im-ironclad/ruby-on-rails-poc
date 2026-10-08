module Api
  class BondsController < BaseController
    def create
      bond = Bonds::Create.call(bond_params)
      render json: BondSerializer.with_schedule(bond), status: :created
    end

    private

    # Strong params: only these keys reach the model. Anything else in the request is dropped.
    def bond_params
      params.expect(bond: [:issuer_id, :series_name, :cusip, :par_amount_cents, :coupon_rate, :issued_on, :maturity_on])
    end
  end
end
