# frozen_string_literal: true

class AddSuspendedAtToIdentities < ActiveRecord::Migration[8.1]
  def change
    add_column :identities, :suspended_at, :datetime
  end
end
