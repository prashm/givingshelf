# Be sure to restart your server when you modify this file.

# Sprockets configuration for ActiveAdmin only
# The main app uses Propshaft (Rails 8 default)
if defined?(Sprockets)
  # Version of your assets, change this if you want to expire all your assets.
  Rails.application.config.assets.version = "1.0"

  # Add additional assets to the asset load path.
  # Rails.application.config.assets.paths << Emoji.images_path

  # Precompile ActiveAdmin assets
  Rails.application.config.assets.precompile += %w[active_admin.css active_admin.js]
end
