module ApplicationSite
  module_function

  def config
    Rails.configuration.x.application
  end

  def domain
    config.fetch(:domain)
  end

  def protocol
    config.fetch(:protocol)
  end

  def port
    config[:port].presence
  end

  def host
    port ? "#{domain}:#{port}" : domain
  end

  def base_url
    "#{protocol}://#{host}"
  end

  def subdomain_host(short_name)
    "#{short_name}.#{domain}"
  end

  def subdomain_url(short_name, path = "/")
    normalized_path = path.to_s.start_with?("/") ? path : "/#{path}"
    host_part = port ? "#{subdomain_host(short_name)}:#{port}" : subdomain_host(short_name)
    "#{protocol}://#{host_part}#{normalized_path}"
  end

  def email(local_part)
    "#{local_part}@#{domain}"
  end

  def production_cookie_domain
    ".#{domain}"
  end
end
