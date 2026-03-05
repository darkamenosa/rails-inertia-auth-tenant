# frozen_string_literal: true

class User < ApplicationRecord
  include Named

  belongs_to :identity
  belongs_to :account

  enum :role, { member: 0, admin: 1, owner: 2 }

  validates :name, presence: true

  scope :active, -> { where(active: true) }

  delegate :email, to: :identity

  def admin?
    super || owner?
  end

  def can_change?(other)
    (admin? && !other.owner?) || other == self
  end

  def can_administer?(other)
    admin? && !other.owner? && other != self
  end
end
