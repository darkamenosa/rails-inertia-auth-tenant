# frozen_string_literal: true

class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.boolean :personal, default: true, null: false

      t.timestamps null: false
    end
  end
end
