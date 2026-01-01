class GroupPagesController < ApplicationController
  allow_unauthenticated_access only: [ :show ]

  def show
    @group = CommunityGroup.find_by(short_name: params[:short_name])

    # Render the React app - it will handle the group page display
    render "books/index"
  end
end
