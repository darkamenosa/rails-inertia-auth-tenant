# frozen_string_literal: true

module Identities
  class SessionsController < Devise::SessionsController
    include InertiaFlash
    rate_limit to: 10, within: 3.minutes, only: :create

    def new
      render inertia: "identities/session/new"
    end

    def create
      self.resource = warden.authenticate!(auth_options)
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource)
      redirect_to after_sign_in_path_for(resource)
    end

    def destroy
      signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
      set_flash_message!(:notice, :signed_out) if signed_out
      redirect_to after_sign_out_path_for(resource_name), status: :see_other
    end

    protected

      def after_sign_in_path_for(resource)
        stored_location = stored_location_for(resource)

        if stored_location.present?
          if stored_location == app_path
            app_path
          elsif stored_location.start_with?("/admin") && !resource.staff?
            app_path
          else
            stored_location
          end
        else
          app_path
        end
      end

      def after_sign_out_path_for(_resource)
        root_path
      end
  end
end
