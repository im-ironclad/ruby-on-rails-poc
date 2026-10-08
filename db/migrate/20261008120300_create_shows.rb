class CreateShows < ActiveRecord::Migration[8.1]
  def change
    create_table :shows do |t|
      t.string :title, null: false
      t.string :kind, null: false
      t.string :genre, null: false
      t.integer :year, null: false
      t.text :synopsis, null: false, default: ""
      t.string :poster_url, null: false
      t.timestamps
    end

    add_index :shows, [:title, :year], unique: true
    add_check_constraint :shows, "kind IN ('movie', 'series')", name: "shows_kind_valid"
  end
end
