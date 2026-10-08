class Issuer < ApplicationRecord
  has_many :bonds, dependent: :restrict_with_error
  has_many :debt_service_payments, through: :bonds

  enum :issuer_type, {
    city: "city",
    county: "county",
    school_district: "school_district",
    utility: "utility"
  }, validate: true

  validates :name, presence: true, uniqueness: { scope: :state }
  validates :state, format: { with: /\A[A-Z]{2}\z/, message: "must be a two-letter code" }

  # Principal still owed: sum of principal on payments not yet paid, one row per issuer, in one query.
  def self.outstanding_principal_cents_by_issuer
    joins(bonds: :debt_service_payments)
      .merge(DebtServicePayment.unpaid)
      .group(:id)
      .sum("debt_service_payments.principal_cents")
  end
end
