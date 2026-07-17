module GroupSubdomain
  extend ActiveSupport::Concern

  RESERVED_SUBDOMAINS = CommunityGroup::RESERVED_SHORT_NAMES
  LOOPBACK_HOSTS = %w[127.0.0.1].freeze
  SITE_GROUP_HEADER = "X-Site-Group-Short-Name".freeze

  included do
    before_action :set_current_group_from_request
  end

  private

  def set_current_group_from_request
    Current.group = request_group
  end

  # Single entry point: subdomain (prod) → path (dev pages) → header (dev API)
  def request_group
    @request_group ||= group_from_subdomain || group_from_path || group_from_request_header
  end

  def group_subdomain_request?
    group_from_subdomain.present?
  end

  def group_path_request?
    request_group.present? && group_from_subdomain.blank?
  end

  def group_url_mode
    return "subdomain" if group_subdomain_request?
    return "path" if group_path_request?
    "none"
  end

  def group_subdomain_short_name
    host = request.host.to_s.downcase
    host_suffix = ".#{ApplicationSite.domain}"
    return nil unless host.end_with?(host_suffix)
    return nil if host == ApplicationSite.domain || host == "www.#{ApplicationSite.domain}"

    short_name = host.delete_suffix(host_suffix)
    return nil if short_name.blank? || short_name.include?(".")
    return nil if RESERVED_SUBDOMAINS.include?(short_name)

    short_name
  end

  def group_from_subdomain
    return @group_from_subdomain if defined?(@group_from_subdomain)

    short_name = group_subdomain_short_name
    @group_from_subdomain = short_name.present? ? CommunityGroup.find_by(short_name: short_name) : nil
  end

  def group_from_path
    return @group_from_path if defined?(@group_from_path)
    return @group_from_path = nil unless local_dev_host?

    short_name = params[:short_name].presence
    if short_name.blank?
      match = request.path.to_s.match(%r{\A/g/([^/]+)})
      short_name = match[1] if match
    end

    return @group_from_path = nil if short_name.blank? || RESERVED_SUBDOMAINS.include?(short_name)

    @group_from_path = CommunityGroup.find_by(short_name: short_name)
  end

  def group_from_request_header
    return @group_from_request_header if defined?(@group_from_request_header)
    return @group_from_request_header = nil unless local_dev_host?

    short_name = request.headers[SITE_GROUP_HEADER].to_s.strip.downcase.presence
    return @group_from_request_header = nil if short_name.blank? || RESERVED_SUBDOMAINS.include?(short_name)

    @group_from_request_header = CommunityGroup.find_by(short_name: short_name)
  end

  # Apex/loopback hosts used for path-based group URLs (before redirect), not group subdomains.
  def local_dev_host?
    host = request.host.to_s.downcase
    return true if LOOPBACK_HOSTS.include?(host)
    return true if host == "localhost"
    return true if !Rails.env.production? && host == ApplicationSite.domain

    false
  end

  def email_matches_group_domain?(email, group)
    return true if group.blank? || group.domain.blank?
    return false if email.blank?

    email.to_s.strip.downcase.split("@").last == group.domain.downcase
  end

  def user_in_domain_locked_group?(user)
    return false unless user

    user.community_groups.where.not(domain: [ nil, "" ]).exists?
  end

  def domain_locked_groups_for(user)
    return CommunityGroup.none unless user

    user.community_groups.where.not(domain: [ nil, "" ])
  end

  def join_restricted_for_user?(user, target_group)
    return false unless user && target_group

    if request_group.present? && target_group.id != request_group.id
      return true
    end

    locked = domain_locked_groups_for(user)
    locked.exists? && !locked.exists?(id: target_group.id)
  end

  def join_restriction_error_message
    if request_group.present?
      "You can only join #{request_group.name} from this site."
    else
      "Your account is linked to an organization group and cannot join other groups."
    end
  end
end
