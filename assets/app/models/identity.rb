# frozen_string_literal: true

class Identity < ApplicationRecord
  include PgSearch::Model

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  has_many :users, dependent: :destroy
  has_many :accounts, through: :users
  before_destroy :capture_account_ids_for_cleanup, prepend: true
  after_destroy_commit :destroy_orphaned_accounts

  # Full-text search: email (primary), user names (secondary)
  # prefix: true allows partial word matching ("tuy" matches "Tuyen")
  pg_search_scope :search,
    against: { email: "A" },
    associated_against: { users: [ :name ] },
    using: { tsearch: { prefix: true } }

  scope :active, -> { where(suspended_at: nil) }
  scope :suspended, -> { where.not(suspended_at: nil) }

  def mark_password_set
    update_column(:password_set_by_user, true) unless password_set_by_user?
  end

  def suspend
    update!(suspended_at: Time.current)
  end

  def reactivate
    update!(suspended_at: nil)
  end

  def suspended?
    suspended_at.present?
  end

  def grant_staff_access
    update!(staff: true)
  end

  def revoke_staff_access
    update!(staff: false)
  end

  def display_name
    users.order(:created_at).first&.name
  end

  def auth_method
    provider.present? ? provider.titleize : "Email"
  end

  def status
    suspended? ? "suspended" : "active"
  end

  # Block suspended identities from signing in
  def active_for_authentication?
    super && !suspended? && users.active.exists?
  end

  def inactive_message
    if suspended?
      :suspended
    elsif users.active.exists?
      super
    else
      :no_membership
    end
  end

  private
    def capture_account_ids_for_cleanup
      @account_ids_for_cleanup = users.distinct.pluck(:account_id)
    end

    def destroy_orphaned_accounts
      if @account_ids_for_cleanup.present?
        Account.where(id: @account_ids_for_cleanup).where.missing(:users).find_each(&:destroy)
      end
    end
end
