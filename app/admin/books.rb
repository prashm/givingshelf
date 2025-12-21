ActiveAdmin.register Book do
  permit_params :title, :author, :summary, :condition, :isbn, :genre, :published_year,
                :status, :view_count, :personal_note, :pickup_method, :pickup_address,
                :user_id

  index do
    selectable_column
    id_column
    column :title
    column :author
    column :genre
    column :condition
    column :status do |book|
      BookStatus.display_status(book.status)
    end
    column :user do |book|
      link_to book.user.email_address, admin_user_path(book.user)
    end
    column :view_count
    column :created_at
    actions
  end

  filter :title
  filter :author
  filter :genre
  filter :condition
  filter :status, as: :select, collection: BookStatus.collection
  filter :user
  filter :created_at

  show do
    attributes_table do
      row :id
      row :title
      row :author
      row :summary
      row :condition
      row :isbn
      row :genre
      row :published_year
      row :status do |book|
        BookStatus.display_status(book.status)
      end
      row :user do |book|
        link_to book.user.email_address, admin_user_path(book.user)
      end
      row :view_count
      row :personal_note
      row :pickup_method
      row :pickup_address
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs "Book Details" do
      f.input :user, collection: User.all.map { |u| [ u.email_address, u.id ] }
      f.input :title
      f.input :author
      f.input :summary
      f.input :condition, as: :select, collection: %w[excellent good fair poor]
      f.input :isbn
      f.input :genre
      f.input :published_year
      f.input :status, as: :select, collection: BookStatus.collection
      f.input :view_count
      f.input :personal_note
      f.input :pickup_method
      f.input :pickup_address
    end
    f.actions
  end
end
