class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :books, dependent: :destroy
  has_many :book_requests, class_name: 'BookRequest', foreign_key: 'requester_id', dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :first_name, :last_name, with: ->(name) { name.strip.titleize }
  normalizes :zip_code, with: ->(zip) { zip.strip }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :last_name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :zip_code, presence: true, format: { with: /\A\d{5}(-\d{4})?\z/, message: "must be a valid US zip code" }
  validates :phone, presence: true, format: { with: /\A\+?1?\d{10,15}\z/, message: "must be a valid phone number" }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  scope :verified, -> { where(verified: true) }
  scope :by_zip_code, ->(zip_code) { where(zip_code: zip_code) }

  def full_name
    "#{first_name} #{last_name}"
  end

  def display_name
    verified? ? full_name : "#{first_name} #{last_name[0]}."
  end

  def location
    zip_code
  end
end
