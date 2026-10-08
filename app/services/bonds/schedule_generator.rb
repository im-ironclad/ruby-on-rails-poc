module Bonds
  # Pure calculation: given a bond's terms, return the level-principal annual debt service schedule.
  # No database access, so it is fast to test and safe to call anywhere.
  #
  # Level principal: the same principal is retired every year, so interest shrinks as the balance falls.
  # Simplification: real municipal bonds usually pay interest semiannually. This POC pays annually.
  class ScheduleGenerator
    Row = Data.define(:due_on, :principal_cents, :interest_cents)

    def initialize(par_amount_cents:, coupon_rate:, issued_on:, maturity_on:)
      @par_amount_cents = par_amount_cents
      @coupon_rate = BigDecimal(coupon_rate.to_s)
      @issued_on = issued_on
      @maturity_on = maturity_on
    end

    def rows
      dates = due_dates
      base_principal, remainder = @par_amount_cents.divmod(dates.size)
      outstanding = @par_amount_cents

      dates.each_with_index.map do |due_on, index|
        principal = base_principal + (index == dates.size - 1 ? remainder : 0)
        interest = (outstanding * @coupon_rate).round(0, BigDecimal::ROUND_HALF_EVEN).to_i
        outstanding -= principal
        Row.new(due_on:, principal_cents: principal, interest_cents: interest)
      end
    end

    private

    # Every anniversary of the issue date before maturity, then maturity itself.
    def due_dates
      anniversaries = (1..).lazy.map { |years| @issued_on.advance(years:) }.take_while { |date| date < @maturity_on }.to_a
      anniversaries + [@maturity_on]
    end
  end
end
