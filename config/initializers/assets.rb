# Be sure to restart your server when you modify this file.

# Sprockets configuration for ActiveAdmin only
# The main app uses Propshaft (Rails 8 default)
if defined?(Sprockets)
  # Version of your assets, change this if you want to expire all your assets.
  Rails.application.config.assets.version = "1.0"

  # Precompile ActiveAdmin assets
  Rails.application.config.assets.precompile += %w[active_admin.css active_admin.js]

  # Configure Sprockets to not process plain CSS files (only SCSS)
  # This prevents SassC from trying to parse modern CSS syntax in CSS files
  Rails.application.config.assets.configure do |env|
    # Unregister the CSS processor that uses SassC
    env.unregister_preprocessor("text/css", Sprockets::SassProcessor) rescue nil
  end
end
