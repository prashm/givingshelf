ActiveAdmin.register User do
  # Prevent creating admin users via UI
  permit_params :email_address, :first_name, :last_name, :zip_code, :phone,
                :street_address, :city, :state, :verified, :address_verified,
                :trust_score

  # Don't allow password or admin changes via admin interface
  # Admin users can only be created via seeds

  index do
    selectable_column
    id_column
    column :email_address
    column :first_name
    column :last_name
    column :zip_code
    column :verified
    column :admin
    column :trust_score
    column :created_at
    actions
  end

  filter :email_address
  filter :first_name
  filter :last_name
  filter :zip_code
  filter :verified
  filter :admin
  filter :created_at

  show do
    attributes_table do
      row :id
      row :email_address
      row :first_name
      row :last_name
      row :zip_code
      row :phone
      row :street_address
      row :city
      row :state
      row :verified
      row :admin
      row :address_verified
      row :trust_score
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs "User Details" do
      f.input :email_address
      f.input :first_name
      f.input :last_name
      f.input :zip_code
      f.input :phone
      f.input :street_address
      f.input :city
      f.input :state
      f.input :verified
      f.input :address_verified
      f.input :trust_score
    end
    f.actions
  end
end
