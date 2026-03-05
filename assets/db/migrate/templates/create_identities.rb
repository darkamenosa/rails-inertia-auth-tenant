# frozen_string_literal: true

class CreateIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :identities do |t|
      ## Database authenticatable
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## OmniAuth
      t.string :provider
      t.string :uid

      ## Custom
      t.boolean :password_set_by_user, default: false, null: false
      t.boolean :staff, default: false, null: false

      t.timestamps null: false
    end

    add_index :identities, :email, unique: true
    add_index :identities, :reset_password_token, unique: true
    add_index :identities, [ :provider, :uid ], unique: true
  end
end
