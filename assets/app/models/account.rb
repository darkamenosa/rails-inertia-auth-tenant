# frozen_string_literal: true

class Account < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :identities, through: :users

  validates :name, presence: true

  def self.create_with_user(identity:, name:)
    first_name = name.strip.split(" ", 2).first
    transaction do
      account = create!(name: "#{first_name}'s Workspace", personal: true)
      user = identity.users.create!(account: account, name: name, role: :owner)
      [ user, account ]
    end
  end

  def slug = "/app/#{AccountSlug.encode(id)}"

  def owner = users.find_by(role: :owner)
end
