Rails.application.config.session_store :active_record_store,
  key: "_givingshelf_session",
  expire_after: 2.weeks,
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax
