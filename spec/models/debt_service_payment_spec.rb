require "rails_helper"

RSpec.describe DebtServicePayment do
  let(:today) { Date.new(2026, 10, 8) }

  describe "#status" do
    it "is paid when paid_on is set, even if the due date has passed" do
      payment = build(:debt_service_payment, due_on: today - 30, paid_on: today - 31)
      expect(payment.status(today)).to eq(:paid)
    end

    it "is overdue when unpaid and past due" do
      expect(build(:debt_service_payment, due_on: today - 1).status(today)).to eq(:overdue)
    end

    it "is upcoming when unpaid and due today or later" do
      expect(build(:debt_service_payment, due_on: today).status(today)).to eq(:upcoming)
    end
  end

  describe ".due_within" do
    it "returns unpaid payments due on or before the window end, including overdue ones" do
      bond = create(:bond)
      overdue = create(:debt_service_payment, bond:, due_on: today - 5)
      soon = create(:debt_service_payment, bond:, due_on: today + 30)
      create(:debt_service_payment, bond:, due_on: today + 31)
      create(:debt_service_payment, bond:, due_on: today + 1, paid_on: today - 1)

      expect(described_class.due_within(30, today:)).to contain_exactly(overdue, soon)
    end
  end

  it "rejects a future paid_on" do
    payment = build(:debt_service_payment, paid_on: Date.current + 1)
    expect(payment).not_to be_valid
    expect(payment.errors[:paid_on]).to include("can't be in the future")
  end
end
