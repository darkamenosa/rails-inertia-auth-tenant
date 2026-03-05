# frozen_string_literal: true

module App
  class SettingsController < BaseController
    def show
      render inertia: "app/settings/show", props: {
        name: Current.user.name,
        email: Current.identity.email,
        password_changeable: Current.identity.password_set_by_user?
      }
    end

    def update
      if password_change?
        update_password
      else
        update_profile
      end
    end

    def destroy
      Current.identity.destroy
      redirect_to root_path, notice: "Your account has been deleted."
    end

    private
      def update_profile
        if Current.user.update(profile_params)
          redirect_to app_settings_path(account_id: Current.account.id), notice: "Profile updated."
        else
          redirect_to app_settings_path(account_id: Current.account.id), alert: Current.user.errors.full_messages.to_sentence
        end
      end

      def update_password
        if Current.identity.update_with_password(password_params)
          bypass_sign_in(Current.identity)
          redirect_to app_settings_path(account_id: Current.account.id), notice: "Password updated."
        else
          redirect_to app_settings_path(account_id: Current.account.id), alert: Current.identity.errors.full_messages.to_sentence
        end
      end

      def password_change?
        params.dig(:settings, :current_password).present?
      end

      def profile_params
        params.expect(settings: [ :name ])
      end

      def password_params
        params.expect(settings: [ :current_password, :password, :password_confirmation ])
      end
  end
end
