class CreateDebtServicePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :debt_service_payments do |t|
      t.references :bond, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.date :due_on, null: false
      t.bigint :principal_cents, null: false
      t.bigint :interest_cents, null: false
      t.date :paid_on
      t.timestamps
    end

    # One payment per bond per date. Also serves bond_id lookups (leading column), so no separate bond_id index.
    add_index :debt_service_payments, [:bond_id, :due_on], unique: true
    # Partial index: the dashboard only ever asks "which UNPAID payments are due soon?"
    add_index :debt_service_payments, :due_on, where: "paid_on IS NULL", name: "index_unpaid_payments_on_due_on"
    add_check_constraint :debt_service_payments, "principal_cents >= 0 AND interest_cents >= 0", name: "payments_amounts_non_negative"
  end
end
