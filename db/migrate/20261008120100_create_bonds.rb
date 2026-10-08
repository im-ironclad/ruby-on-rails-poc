class CreateBonds < ActiveRecord::Migration[8.1]
  def change
    create_table :bonds do |t|
      t.references :issuer, null: false, foreign_key: true
      t.string :series_name, null: false
      t.string :cusip, null: false, limit: 9
      t.bigint :par_amount_cents, null: false
      t.decimal :coupon_rate, null: false, precision: 7, scale: 5
      t.date :issued_on, null: false
      t.date :maturity_on, null: false
      t.timestamps
    end

    add_index :bonds, :cusip, unique: true
    add_check_constraint :bonds, "par_amount_cents > 0", name: "bonds_par_amount_positive"
    add_check_constraint :bonds, "coupon_rate >= 0 AND coupon_rate < 1", name: "bonds_coupon_rate_is_fraction"
    add_check_constraint :bonds, "maturity_on > issued_on", name: "bonds_matures_after_issue"
  end
end
