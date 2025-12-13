# Be sure to restart your server when you modify this file.

# Sprockets configuration for ActiveAdmin only
# The main app uses Propshaft (Rails 8 default)
# Note: SCSS files are compiled to CSS during assets:precompile, then removed
if defined?(Sprockets)
  # Version of your assets, change this if you want to expire all your assets.
  Rails.application.config.assets.version = "1.0"

  # Precompile ActiveAdmin assets (SCSS will be compiled to CSS during build)
  Rails.application.config.assets.precompile += %w[active_admin.css active_admin.js]
end
