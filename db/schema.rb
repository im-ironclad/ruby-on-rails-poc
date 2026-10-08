# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_08_120400) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bonds", force: :cascade do |t|
    t.bigint "issuer_id", null: false
    t.string "series_name", null: false
    t.string "cusip", limit: 9, null: false
    t.bigint "par_amount_cents", null: false
    t.decimal "coupon_rate", precision: 7, scale: 5, null: false
    t.date "issued_on", null: false
    t.date "maturity_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cusip"], name: "index_bonds_on_cusip", unique: true
    t.index ["issuer_id"], name: "index_bonds_on_issuer_id"
    t.check_constraint "coupon_rate >= 0::numeric AND coupon_rate < 1::numeric", name: "bonds_coupon_rate_is_fraction"
    t.check_constraint "maturity_on > issued_on", name: "bonds_matures_after_issue"
    t.check_constraint "par_amount_cents > 0", name: "bonds_par_amount_positive"
  end

  create_table "debt_service_payments", force: :cascade do |t|
    t.bigint "bond_id", null: false
    t.date "due_on", null: false
    t.bigint "principal_cents", null: false
    t.bigint "interest_cents", null: false
    t.date "paid_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bond_id", "due_on"], name: "index_debt_service_payments_on_bond_id_and_due_on", unique: true
    t.index ["due_on"], name: "index_unpaid_payments_on_due_on", where: "(paid_on IS NULL)"
    t.check_constraint "principal_cents >= 0 AND interest_cents >= 0", name: "payments_amounts_non_negative"
  end

  create_table "issuers", force: :cascade do |t|
    t.string "name", null: false
    t.string "issuer_type", null: false
    t.string "state", limit: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["state", "name"], name: "index_issuers_on_state_and_name", unique: true
    t.check_constraint "issuer_type::text = ANY (ARRAY['city'::character varying, 'county'::character varying, 'school_district'::character varying, 'utility'::character varying]::text[])", name: "issuers_issuer_type_valid"
    t.check_constraint "state::text ~ '^[A-Z]{2}$'::text", name: "issuers_state_is_two_letter_code"
  end

  create_table "list_entries", force: :cascade do |t|
    t.bigint "show_id", null: false
    t.string "status", default: "want_to_watch", null: false
    t.integer "rating", limit: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["show_id"], name: "index_list_entries_on_show_id", unique: true
    t.check_constraint "rating IS NULL OR rating >= 1 AND rating <= 5", name: "list_entries_rating_range"
    t.check_constraint "status::text = ANY (ARRAY['want_to_watch'::character varying, 'watching'::character varying, 'watched'::character varying]::text[])", name: "list_entries_status_valid"
  end

  create_table "shows", force: :cascade do |t|
    t.string "title", null: false
    t.string "kind", null: false
    t.string "genre", null: false
    t.integer "year", null: false
    t.text "synopsis", default: "", null: false
    t.string "poster_url", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["title", "year"], name: "index_shows_on_title_and_year", unique: true
    t.check_constraint "kind::text = ANY (ARRAY['movie'::character varying, 'series'::character varying]::text[])", name: "shows_kind_valid"
  end

  add_foreign_key "bonds", "issuers"
  add_foreign_key "debt_service_payments", "bonds", on_delete: :cascade
  add_foreign_key "list_entries", "shows", on_delete: :cascade
end
