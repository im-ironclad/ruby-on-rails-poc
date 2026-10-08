class DebtServicePayment < ApplicationRecord
  belongs_to :bond

  scope :unpaid, -> { where(paid_on: nil) }
  scope :due_within, ->(days, today: Date.current) { unpaid.where(due_on: ..(today + days)) }

  validates :due_on, presence: true
  validates :principal_cents, :interest_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :paid_on_not_in_future

  # Status is derived from paid_on and the date, never stored, so it can never drift out of sync.
  def status(today = Date.current)
    if paid_on
      :paid
    elsif due_on < today
      :overdue
    else
      :upcoming
    end
  end

  def paid?
    paid_on.present?
  end

  def total_cents
    principal_cents + interest_cents
  end

  private

  def paid_on_not_in_future
    errors.add(:paid_on, "can't be in the future") if paid_on && paid_on > Date.current
  end
end
