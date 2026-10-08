module Api
  class DebtServicePaymentsController < BaseController
    def update
      payment = DebtServicePayment.find(params[:id])
      payment.update!(payment_params)
      render json: PaymentSerializer.call(payment)
    end

    private

    # Only paid_on is editable. Amounts come from the schedule and never change through the API.
    def payment_params
      params.expect(debt_service_payment: [:paid_on])
    end
  end
end
