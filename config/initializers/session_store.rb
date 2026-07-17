Rails.application.config.session_store :active_record_store,
  key: "_givingshelf_session",
  expire_after: 2.weeks,
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax,
  # Share session across apex and group subdomains in production
  domain: Rails.env.production? ? ".#{Rails.configuration.x.application.fetch(:domain)}" : :all
