Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Set traces_sample_rate to 1.0 to capture 100%
  # of the transactions for performance monitoring.
  # We recommend adjusting this value in production.
  config.traces_sample_rate = ENV.fetch('SENTRY_TRACES_SAMPLE_RATE', '0.1').to_f

  # Set profiles_sample_rate to profile 100% of sampled transactions.
  # We recommend adjusting this value in production.
  config.profiles_sample_rate = ENV.fetch('SENTRY_PROFILES_SAMPLE_RATE', '0.1').to_f

  # Set environment
  config.environment = Rails.env

  # Set release version (useful for tracking deployments)
  config.release = ENV['SENTRY_RELEASE'] if ENV['SENTRY_RELEASE'].present?

  # Filter out sensitive parameters
  config.before_send = lambda do |event, hint|
    # Filter out sensitive data from params
    if event.request && event.request.data
      event.request.data = event.request.data.except('password', 'password_confirmation', 'token', 'secret')
    end
    event
  end

  # Only send events in production and staging
  config.enabled_environments = %w[production staging]
end

