class AddOtpFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :otp_secret, :string
    add_column :users, :otp_sent_at, :datetime
    add_column :users, :otp_attempts, :integer, default: 0
  end
end
