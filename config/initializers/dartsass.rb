# Configure dartsass-rails to skip default builds
# We only use Sprockets for ActiveAdmin, not for the main app (which uses Propshaft)
# This prevents dartsass-rails from looking for application.scss
if defined?(DartSass::Rails)
  Rails.application.config.dartsass.builds = {}
end

