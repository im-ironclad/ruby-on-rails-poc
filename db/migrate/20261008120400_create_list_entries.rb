class CreateListEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :list_entries do |t|
      t.references :show, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :status, null: false, default: "want_to_watch"
      t.integer :rating, limit: 2
      t.timestamps
    end

    add_check_constraint :list_entries, "status IN ('want_to_watch', 'watching', 'watched')", name: "list_entries_status_valid"
    add_check_constraint :list_entries, "rating IS NULL OR rating BETWEEN 1 AND 5", name: "list_entries_rating_range"
  end
end
