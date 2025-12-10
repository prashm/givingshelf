class AddAddressAndTrustScoreToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :street_address, :string
    add_column :users, :city, :string
    add_column :users, :state, :string
    add_column :users, :address_verified, :boolean, default: false, null: false
    add_column :users, :trust_score, :integer, default: 0, null: false
  end
end
