# frozen_string_literal: true

class InertiaController < ApplicationController
  include InertiaFlash
  include InertiaUtils

  inertia_share current_user: -> { current_user_props }

  private

    def current_user_props
      return nil unless Current.identity

      user = Current.user || Current.identity.users.order(:created_at).first

      {
        id: Current.identity.id,
        name: user&.name || Current.identity.email.split("@").first,
        email: Current.identity.email,
        role: user&.role,
        staff: Current.identity.staff?,
        account_id: user&.account_id,
        account_name: user&.account&.name
      }
    end
end
