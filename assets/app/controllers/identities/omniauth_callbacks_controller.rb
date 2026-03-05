# frozen_string_literal: true

module Identities
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    include InertiaFlash

    def google_oauth2
      auth = request.env["omniauth.auth"]

      identity = find_or_create_identity(auth)

      if identity.active_for_authentication?
        sign_in(:identity, identity)
        redirect_to app_path, notice: "Signed in with Google."
      else
        redirect_to new_identity_session_path, alert: I18n.t("devise.failure.#{identity.inactive_message}")
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      redirect_to new_identity_session_path, alert: "Google sign-in failed."
    end

    private
      def find_or_create_identity(auth)
        retries ||= 0

        Identity.transaction do
          identity = Identity.find_by(provider: auth.provider, uid: auth.uid) ||
            Identity.find_by(email: auth.info.email)

          if identity
            if identity.provider.blank? || identity.uid.blank?
              identity.update!(provider: auth.provider, uid: auth.uid)
            end
          else
            identity = Identity.create!(
              email: auth.info.email,
              password: Devise.friendly_token.first(20),
              provider: auth.provider,
              uid: auth.uid
            )
          end

          unless identity.users.exists?
            user_name = auth.info.name.presence || identity.email.split("@").first
            Account.create_with_user(identity: identity, name: user_name)
          end

          identity
        end
      rescue ActiveRecord::RecordNotUnique
        retries += 1
        retry if retries <= 1
        raise
      end
  end
end
