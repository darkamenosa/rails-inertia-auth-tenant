# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.references :identity, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :role, default: 0, null: false
      t.boolean :active, default: true, null: false

      t.timestamps null: false
    end

    add_index :users, [ :identity_id, :account_id ], unique: true
  end
end
