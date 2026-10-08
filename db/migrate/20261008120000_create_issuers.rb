class CreateIssuers < ActiveRecord::Migration[8.1]
  def change
    create_table :issuers do |t|
      t.string :name, null: false
      t.string :issuer_type, null: false
      t.string :state, null: false, limit: 2
      t.timestamps
    end

    add_index :issuers, [:state, :name], unique: true
    add_check_constraint :issuers, "issuer_type IN ('city', 'county', 'school_district', 'utility')", name: "issuers_issuer_type_valid"
    add_check_constraint :issuers, "state ~ '^[A-Z]{2}$'", name: "issuers_state_is_two_letter_code"
  end
end
