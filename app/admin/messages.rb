ActiveAdmin.register Message do
  permit_params :item_request_id, :user_id, :content, :read_at

  index do
    selectable_column
    id_column
    column :item_request do |message|
      link_to "Request ##{message.item_request_id}", admin_item_request_path(message.item_request)
    end
    column :user do |message|
      link_to message.user.email_address, admin_user_path(message.user)
    end
    column :content do |message|
      truncate(message.content, length: 50)
    end
    column :read_at
    column :created_at
    actions
  end

  filter :book_request
  filter :user
  filter :read_at
  filter :created_at

  show do
    attributes_table do
      row :id
      row :book_request do |message|
        link_to "Request ##{message.book_request_id}", admin_book_request_path(message.book_request)
      end
      row :user do |message|
        link_to message.user.email_address, admin_user_path(message.user)
      end
      row :content
      row :read_at
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs "Message Details" do
      f.input :item_request, collection: ItemRequest.all.map { |ir| [ "#{ir.item.type}: #{ir.item.title} - Requester: #{ir.requester.email_address}", ir.id ] }
      f.input :user, collection: User.all.map { |u| [ u.email_address, u.id ] }
      f.input :content
      f.input :read_at, as: :date_time_picker
    end
    f.actions
  end
end
