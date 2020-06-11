class Account < ApplicationRecord
  has_many :participants
  has_many :retrospectives, through: :participants

  has_secure_password
  has_secure_token :password_reset_token

  validates :email, uniqueness: true

  before_create :clear_password_reset_token

  def self.from_omniauth(auth)
    where(email: auth.info.email).first_or_initialize do |account|
      account.username = auth.info.name
      account.email = auth.info.email
      account.password = SecureRandom.hex
    end
  end

  def clear_password_reset_token
    self.password_reset_token = nil
  end
end
