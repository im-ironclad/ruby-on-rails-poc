module Bonds
  # Creates a bond and its full payment schedule as one unit of work.
  # Either every row commits or none do: a bond without a schedule is an invalid state.
  class Create
    def self.call(attributes)
      new(attributes).call
    end

    def initialize(attributes)
      @attributes = attributes
    end

    # Raises ActiveRecord::RecordInvalid on bad input. The transaction rolls back automatically.
    def call
      bond = Bond.new(@attributes)

      Bond.transaction do
        bond.save!
        schedule_for(bond).each do |row|
          bond.debt_service_payments.create!(row.to_h)
        end
      end

      bond
    end

    private

    def schedule_for(bond)
      ScheduleGenerator.new(
        par_amount_cents: bond.par_amount_cents,
        coupon_rate: bond.coupon_rate,
        issued_on: bond.issued_on,
        maturity_on: bond.maturity_on
      ).rows
    end
  end
end
