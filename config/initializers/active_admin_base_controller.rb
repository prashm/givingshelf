# Monkey-patch ActiveAdmin::BaseController to skip require_authentication
# ActiveAdmin has its own authentication via authenticate_admin_user!
Rails.application.config.to_prepare do
  if defined?(ActiveAdmin::BaseController)
    ActiveAdmin::BaseController.skip_before_action :require_authentication
  end
end

