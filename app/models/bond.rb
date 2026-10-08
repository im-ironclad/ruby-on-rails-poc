class Bond < ApplicationRecord
  belongs_to :issuer
  has_many :debt_service_payments, -> { order(:due_on) }, dependent: :destroy, inverse_of: :bond

  validates :series_name, presence: true
  validates :cusip, presence: true, uniqueness: true, format: { with: /\A[0-9A-Z]{9}\z/, message: "must be 9 uppercase letters or digits" }
  validates :par_amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :coupon_rate, numericality: { greater_than_or_equal_to: 0, less_than: 1 }
  validates :issued_on, :maturity_on, presence: true
  validate :matures_after_issue

  def outstanding_principal_cents
    debt_service_payments.reject(&:paid?).sum(&:principal_cents)
  end

  private

  def matures_after_issue
    return if issued_on.blank? || maturity_on.blank?

    errors.add(:maturity_on, "must be after the issue date") unless maturity_on > issued_on
  end
end
