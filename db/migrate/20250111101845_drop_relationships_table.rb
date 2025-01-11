class DropRelationshipsTable < ActiveRecord::Migration[8.0]
  def up
    drop_table :relationships
  end

  def down
    create_table :relationships, charset: "utf8mb4", collation: "utf8mb4_ja_0900_as_cs" do |t|
      t.bigint "user_id", null: false
      t.bigint "associate_id", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false

      t.index ["associate_id"], name: "index_relationships_on_associate_id"
      t.index %w[user_id associate_id], name: "index_relationships_on_user_id_and_associate_id", unique: true
      t.index ["user_id"], name: "index_relationships_on_user_id"
    end
  end
end
