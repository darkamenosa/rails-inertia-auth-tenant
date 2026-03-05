# frozen_string_literal: true

class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  before_action :set_current_attributes
  before_action :store_user_location, if: :storable_location?
  before_action :configure_permitted_parameters, if: :devise_controller?

  # Global error handling
  rescue_from StandardError, with: :handle_internal_error
  rescue_from ActionController::RoutingError, ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_session_expired
  rescue_from ActionController::UnknownFormat, with: :handle_unknown_format

  private

    def set_current_attributes
      Current.identity = current_identity if respond_to?(:current_identity)
      Current.request_id = request.uuid
      Current.user_agent = request.user_agent
      Current.ip_address = request.remote_ip
    end

    def require_active_identity!
      if Current.identity.present? && !Current.identity.active_for_authentication?
        inactive_message = Current.identity.inactive_message
        sign_out(:identity)
        Current.reset
        redirect_to new_identity_session_path, alert: I18n.t("devise.failure.#{inactive_message}")
      end
    end

    def current_user
      Current.user
    end
    helper_method :current_user

    # Devise: store location for post-login redirect
    def storable_location?
      request.get? && is_navigational_format? && !devise_controller? && !request.xhr?
    end

    def store_user_location
      store_location_for(:identity, request.fullpath)
    end

    # Permit only default Devise fields — extra params (e.g. user name)
    # are handled explicitly in each controller via params.expect
    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: [])
      devise_parameter_sanitizer.permit(:account_update, keys: [])
    end

    def handle_internal_error(exception)
      raise exception unless Rails.env.production?

      Rails.logger.error(exception.full_message)
      render_error_page(500, "Server Error", "Something went wrong on our end.")
    end

    def handle_not_found(_exception = nil)
      render_error_page(404, "Page Not Found", "The page you're looking for doesn't exist or has been moved.")
    end

    def handle_session_expired(_exception = nil)
      render_error_page(419, "Session Expired", "Your session has expired. Please refresh the page and try again.")
    end

    def handle_unknown_format(_exception = nil)
      render_error_page(406, "Not Acceptable", "The requested format is not supported.")
    end

    def render_error_page(status, title, message)
      component = if request.path.start_with?("/admin")
        "admin/errors/show"
      elsif request.path.start_with?("/app")
        "app/errors/show"
      else
        "errors/show"
      end

      respond_to do |format|
        format.html { render inertia: component, props: { status:, title:, message: }, status: }
        format.json { render json: { error: message, status: }, status: }
        format.any { head status }
      end
    end
end
