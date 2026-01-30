ActiveAdmin.register GroupItemAvailability do
  permit_params :item_id, :community_group_id

  index do
    selectable_column
    id_column
    column :item do |availability|
      item = availability.item
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
    column :community_group do |availability|
      link_to availability.community_group.name, admin_community_group_path(availability.community_group)
    end
    column :created_at
    actions
  end

  filter :item
  filter :community_group
  filter :created_at

  show do
    attributes_table do
      row :id
      row :item do |availability|
        item = availability.item
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
      row :community_group do |availability|
        link_to availability.community_group.name, admin_community_group_path(availability.community_group)
      end
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs "Group Item Availability Details" do
      f.input :item, collection: Item.all.map { |i| [ "#{i.type}: #{i.title}", i.id ] }
      f.input :community_group, collection: CommunityGroup.all.map { |g| [ g.name, g.id ] }
    end
    f.actions
  end
end
