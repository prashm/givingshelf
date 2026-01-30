ActiveAdmin.register ItemRequest do
  permit_params :requester_id, :item_id, :owner_id, :status, :message

  index do
    selectable_column
    id_column
    column :item do |request|
      item = request.item
      link_text = case item.type
      when "Book"
                    "#{item.title} by #{item.author}"
      when "Toy"
                    "#{item.title} (#{item.brand})"
      else
                    item.title
      end
      link_to link_text, (item.is_a?(Book) ? admin_book_path(item) : admin_toy_path(item))
    end
    column :requester do |request|
      link_to request.requester.email_address, admin_user_path(request.requester)
    end
    column :owner do |request|
      link_to request.owner.email_address, admin_user_path(request.owner)
    end
    column :status do |request|
      BookRequestService.new.display_status(request.status)
    end
    column :message
    column :created_at
    actions
  end

  filter :item
  filter :requester
  filter :owner
  filter :status, as: :select, collection: {
    "Pending" => ItemRequest::PENDING_STATUS,
    "Accepted" => ItemRequest::ACCEPTED_STATUS,
    "Declined" => ItemRequest::DECLINED_STATUS,
    "In Review" => ItemRequest::IN_REVIEW_STATUS,
    "Completed" => ItemRequest::COMPLETED_STATUS
  }
  filter :created_at

  show do |item_request|
    attributes_table do
      row :id
      row :item do
        item = item_request.item
        link_text = case item.type
        when "Book"
                      "#{item.title} by #{item.author}"
        when "Toy"
                      "#{item.title} (#{item.brand})"
        else
                      item.title
        end
        link_to link_text, (item.is_a?(Book) ? admin_book_path(item) : admin_toy_path(item))
      end
      row :requester do
        link_to item_request.requester.email_address, admin_user_path(item_request.requester)
      end
      row :owner do
        link_to item_request.owner.email_address, admin_user_path(item_request.owner)
      end
      row :status do
        ItemRequestService.new.display_status(item_request.status)
      end
      row :message
      row :created_at
      row :updated_at
    end

    panel "Messages" do
      table_for item_request.messages.order(created_at: :desc) do
        column :user do |message|
          link_to message.user.email_address, admin_user_path(message.user)
        end
        column :content
        column :read_at
        column :created_at
      end
    end
  end

  form do |f|
    f.inputs "Item Request Details" do
      f.input :item, collection: Item.all.map { |i| [ "#{i.type}: #{i.title}", i.id ] }
      f.input :requester, collection: User.all.map { |u| [ u.email_address, u.id ] }
      f.input :owner, collection: User.all.map { |u| [ u.email_address, u.id ] }
      f.input :status, as: :select, collection: {
        "Pending" => ItemRequest::PENDING_STATUS,
        "Accepted" => ItemRequest::ACCEPTED_STATUS,
        "Declined" => ItemRequest::DECLINED_STATUS,
        "In Review" => ItemRequest::IN_REVIEW_STATUS,
        "Completed" => ItemRequest::COMPLETED_STATUS
      }
      f.input :message
    end
    f.actions
  end
end
