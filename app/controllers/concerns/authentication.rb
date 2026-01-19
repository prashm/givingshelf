module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication, unless: :skip_main_authentication?

    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def skip_main_authentication?
      # ActiveAdmin handles its own authentication using `authenticate_admin_user!`, so we skip the main site authentication
      defined?(ActiveAdmin::BaseController) && is_a?(ActiveAdmin::BaseController)
    end

    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url

      # Handle API requests differently
      if request.format.json? || controller_path.start_with?("api/")
        render json: { error: "Authentication required" }, status: :unauthorized
      else
        redirect_to before_authentication_url
      end
    end

    def before_authentication_url
      new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user, device_fingerprint: nil, suspicious_activity: false)
      session_params = {
        user_agent: request.user_agent,
        ip_address: request.remote_ip,
        suspicious_activity: suspicious_activity
      }
      session_params[:device_fingerprint] = device_fingerprint if device_fingerprint.present?

      user.sessions.create!(session_params).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session&.destroy
      Current.session = nil
      cookies.delete(:session_id)
    end
end
