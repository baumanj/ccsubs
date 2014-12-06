class User < ActiveRecord::Base
  attr_accessor :confirmation_token
  has_many :requests
  has_many :fulfilled_requests, class_name: "Request", foreign_key: "fulfilling_user_id"
  has_many :availabilities
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@([a-z\d\-]+\.)+[a-z]+\z/i
  validates :email, presence: true, format: { with: VALID_EMAIL_REGEX },
    uniqueness: { case_sensitive: false }
  validates :vic, presence: true, uniqueness: true, on: :create
  has_secure_password
  MAX_LOGIN_ATTEMPTS = 10
  # allow_nil so that users can edit their profile w/o entering password
  validates :password, length: { minimum: 5 }, allow_nil: true

  before_create :create_remember_token, :create_confirmation_token

  before_save do
    self.email.downcase!
    if email_changed? && email != User.find(id).email
      self.confirmed = false
    end
    true
  end

  def User.new_secure_token
    SecureRandom.urlsafe_base64
  end

  def to_s
    name
  end

  def User.digest(token)
    Digest::SHA1.hexdigest(token.to_s)
  end

  # Set the user signed in and return the remember token for the cookie
  def try_sign_in(password)
    if !disabled? && authenticate(password)
      remember_token = User.new_secure_token
      self.remember_token = User.digest(remember_token)
      self.failed_login_attempts = 0
    else
      remember_token = nil
      self.failed_login_attempts += 1
      self.disabled = true if self.failed_login_attempts > MAX_LOGIN_ATTEMPTS
    end
    save
    remember_token
  end

  def sign_out
    update_attribute(:remember_token, User.digest(User.new_secure_token))
  end

  def create_confirmation_token
    self.confirmation_token = User.new_secure_token
    update_attribute(:confirmation_digest, User.digest(self.confirmation_token))
  end

  def confirm(token)
    if User.digest(token) == confirmation_digest
      update_attribute(:confirmed, true)
    end
  end

  def future_availabilities
    availabilities.where("date > ?", Date.today).select do |a| 
      a.start > Time.now && a.request.nil?
    end
  end

  private

    def create_remember_token
      self.remember_token = User.digest(User.new_secure_token)
    end
end
