class GroupPagesController < ApplicationController
  allow_unauthenticated_access only: [ :show ]

  def show
    group = CommunityGroup.find_by(short_name: params[:short_name])
    return head :not_found unless group

    suffix = request.path.sub(%r{\A/g/#{Regexp.escape(group.short_name)}}, "")
    suffix = "/" if suffix.blank?
    redirect_to ApplicationSite.subdomain_url(group.short_name, suffix),
                allow_other_host: true, status: :moved_permanently
  end
end
