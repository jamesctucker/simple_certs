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

ActiveRecord::Schema[8.0].define(version: 2025_08_09_192903) do
  create_table "accounts", force: :cascade do |t|
    t.string "name"
    t.integer "organization_id"
    t.index ["organization_id"], name: "index_account_on_organization_id"
  end

  create_table "certificate_quantities", force: :cascade do |t|
    t.integer "quantity"
    t.integer "certificate_id"
    t.integer "account_id"
    t.string "status"
    t.integer "to_organization_id"
    t.datetime "intransit_at"
    t.index ["account_id"], name: "index_certificate_quantities_on_account_id"
    t.index ["certificate_id"], name: "index_certificate_quantities_on_certificate_id"
    t.index ["intransit_at"], name: "index_certificate_quantities_on_intransit_at"
    t.index ["to_organization_id"], name: "index_certificate_quantities_on_to_organization_id"
  end

  create_table "certificates", force: :cascade do |t|
    t.string "sn_base"
    t.integer "quantity"
    t.integer "generation_id"
    t.integer "generator_id"
    t.date "vintage_date"
    t.index ["generation_id"], name: "index_certificates_on_generation_id"
    t.index ["generator_id"], name: "index_certificates_on_generator_id"
  end

  create_table "generations", force: :cascade do |t|
    t.date "start_date"
    t.date "end_date"
    t.integer "quantity"
    t.integer "generator_id"
    t.index ["generator_id"], name: "index_generations_on_generator_id"
  end

  create_table "generators", force: :cascade do |t|
    t.string "name"
    t.string "ext_id"
    t.integer "organization_id"
    t.index ["organization_id"], name: "index_generators_on_organization_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name"
    t.integer "default_account_id"
    t.index ["default_account_id"], name: "index_organizations_on_default_account_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "api_key"
    t.integer "organization_id"
    t.index ["organization_id"], name: "index_users_on_organization_id"
  end
end
