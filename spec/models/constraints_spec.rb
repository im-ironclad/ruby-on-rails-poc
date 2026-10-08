require "rails_helper"

# These bypass model validations on purpose. They prove the database itself refuses bad data,
# which matters for writes that skip ActiveRecord (insert_all, raw SQL, a second app, a console typo).
RSpec.describe "database constraints" do
  it "rejects a duplicate CUSIP" do
    existing = create(:bond)
    duplicate = build(:bond, cusip: existing.cusip)
    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "rejects a bond that matures before it is issued" do
    bond = build(:bond, issued_on: Date.new(2030, 1, 1), maturity_on: Date.new(2020, 1, 1))
    expect { bond.save(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /bonds_matures_after_issue/)
  end

  it "rejects a rating outside 1 to 5" do
    entry = build(:list_entry, rating: 6)
    expect { entry.save(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /list_entries_rating_range/)
  end

  it "rejects a second list entry for the same show" do
    entry = create(:list_entry)
    expect { build(:list_entry, show: entry.show).save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
