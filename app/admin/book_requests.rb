ActiveAdmin.register BookRequest do
  permit_params :requester_id, :book_id, :owner_id, :status, :message

  index do
    selectable_column
    id_column
    column :book do |request|
      link_to request.book.title, admin_book_path(request.book)
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

  filter :book
  filter :requester
  filter :owner
  filter :status, as: :select, collection: {
    "Pending" => BookRequest::PENDING_STATUS,
    "Accepted" => BookRequest::ACCEPTED_STATUS,
    "Declined" => BookRequest::DECLINED_STATUS,
    "In Review" => BookRequest::IN_REVIEW_STATUS,
    "Completed" => BookRequest::COMPLETED_STATUS
  }
  filter :created_at

  show do |book_request|
    attributes_table do
      row :id
      row :book do
        link_to book_request.book.title, admin_book_path(book_request.book)
      end
      row :requester do
        link_to book_request.requester.email_address, admin_user_path(book_request.requester)
      end
      row :owner do
        link_to book_request.owner.email_address, admin_user_path(book_request.owner)
      end
      row :status do
        BookRequestService.new.display_status(book_request.status)
      end
      row :message
      row :created_at
      row :updated_at
    end

    panel "Messages" do
      table_for book_request.messages.order(created_at: :desc) do
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
    f.inputs "Book Request Details" do
      f.input :book, collection: Book.all.map { |b| [ "#{b.title} by #{b.author}", b.id ] }
      f.input :requester, collection: User.all.map { |u| [ u.email_address, u.id ] }
      f.input :owner, collection: User.all.map { |u| [ u.email_address, u.id ] }
      f.input :status, as: :select, collection: {
        "Pending" => BookRequest::PENDING_STATUS,
        "Accepted" => BookRequest::ACCEPTED_STATUS,
        "Declined" => BookRequest::DECLINED_STATUS,
        "In Review" => BookRequest::IN_REVIEW_STATUS,
        "Completed" => BookRequest::COMPLETED_STATUS
      }
      f.input :message
    end
    f.actions
  end
end
