ActiveAdmin.register GroupBookAvailability do
  permit_params :book_id, :community_group_id

  index do
    selectable_column
    id_column
    column :book do |availability|
      link_to availability.book.title, admin_book_path(availability.book)
    end
    column :community_group do |availability|
      link_to availability.community_group.name, admin_community_group_path(availability.community_group)
    end
    column :created_at
    actions
  end

  filter :book
  filter :community_group
  filter :created_at

  show do
    attributes_table do
      row :id
      row :book do |availability|
        link_to availability.book.title, admin_book_path(availability.book)
      end
      row :community_group do |availability|
        link_to availability.community_group.name, admin_community_group_path(availability.community_group)
      end
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs "Group Book Availability Details" do
      f.input :book, collection: Book.all.map { |b| ["#{b.title} by #{b.author}", b.id] }
      f.input :community_group, collection: CommunityGroup.all.map { |g| [g.name, g.id] }
    end
    f.actions
  end
end
