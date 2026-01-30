ActiveAdmin.register Toy do
  permit_params :title, :brand, :age_range, :summary, :condition,
                :status, :view_count, :personal_note, :pickup_method, :pickup_address,
                :user_id

  index do
    selectable_column
    id_column
    column :title
    column :brand
    column :age_range
    column :condition
    column :status do |toy|
      ShareableItemStatus.display_status(toy.status)
    end
    column :user do |toy|
      link_to toy.user.email_address, admin_user_path(toy.user)
    end
    column :view_count
    column :created_at
    actions
  end

  filter :title
  filter :brand
  filter :age_range
  filter :condition
  filter :status, as: :select, collection: ShareableItemStatus.collection
  filter :user
  filter :created_at

  show do
    attributes_table do
      row :id
      row :title
      row :brand
      row :age_range
      row :summary
      row :condition
      row :status do |toy|
        ShareableItemStatus.display_status(toy.status)
      end
      row :user do |toy|
        link_to toy.user.email_address, admin_user_path(toy.user)
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
    f.inputs "Toy Details" do
      f.input :user, collection: User.all.map { |u| [ u.email_address, u.id ] }
      f.input :title
      f.input :brand
      f.input :age_range
      f.input :summary
      f.input :condition, as: :select, collection: %w[excellent good fair poor]
      f.input :status, as: :select, collection: ShareableItemStatus.collection
      f.input :view_count
      f.input :personal_note
      f.input :pickup_method
      f.input :pickup_address
    end
    f.actions
  end
end
