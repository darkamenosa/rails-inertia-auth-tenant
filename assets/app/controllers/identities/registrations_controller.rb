# frozen_string_literal: true

module Identities
  class RegistrationsController < Devise::RegistrationsController
    include InertiaFlash

    def new
      render inertia: "identities/registration/new"
    end

    def create
      email = sign_up_params[:email].to_s.strip
      existing = email.present? ? Identity.find_by(email: email.downcase) : nil

      if existing
        redirect_to new_identity_registration_path,
          inertia: { errors: { email: "Email already registered. Try signing in instead." } }
        return
      end

      build_resource(sign_up_params)
      user_name = user_params[:name].presence || resource.email.to_s.split("@").first

      Identity.transaction do
        resource.save!
        resource.mark_password_set
        Account.create_with_user(identity: resource, name: user_name)
      end

      set_flash_message!(:notice, :signed_up)
      sign_up(resource_name, resource)
      redirect_to after_sign_up_path_for(resource)
    rescue ActiveRecord::RecordInvalid => error
      clean_up_passwords resource
      errors = resource.errors.to_hash
      errors.merge!(error.record.errors.to_hash) unless error.record == resource
      redirect_to new_identity_registration_path, inertia: { errors: errors }
    rescue ActiveRecord::RecordNotUnique
      redirect_to new_identity_registration_path,
        inertia: { errors: { email: "Email already registered. Try signing in instead." } }
    end

    protected

      def after_sign_up_path_for(_resource)
        app_path
      end

    private

      def user_params
        params.expect(user: [ :name ])
      end
  end
end
