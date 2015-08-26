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
    if new_record? || email_changed? && email != User.find(id).email
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

  def upcoming_coverage
    Request.on_or_after(Date.today).fulfilled.select {|r| r.fulfilling_user == self}
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
    self.confirmation_digest = User.digest(self.confirmation_token)
  end

  def update_confirmation_token
    create_confirmation_token
    save!
  end

  def confirmation_token_valid?(token)
    User.digest(token) == confirmation_digest
  end

  def confirm(token)
    if confirmation_token_valid?(token)
      update_attribute(:confirmed, true)
    end
  end

  def open_requests
    future(:requests).select {|r| r.seeking_offers? }
  end
  
  def future(attribute)
    self.send(attribute).where("date >= ?", Date.today).select do |a| 
      a.start > Time.now
    end
  end

  def future_availabilities
    future(:availabilities)
  end
  
  def open_availabilities
    future_availabilities.select {|a| a.request.nil? }
  end
  
  def open_availability(matching_request)
      # We can't be available for our own requests
      unless self == matching_request.user
        open_availabilities.find {|a| a.start == matching_request.start }
      end
  end

  def available?(request)
    a = availability_for(request)
    a.nil? || a.request.nil?
  end

  def availability_for!(request)
    if available?(request)
      availability_for(request) || create_availability!(request)
    end
  end
  
  def pending_offers
    Request.pending_requests(id)
  end

  def pending_offers?
    pending_offers.any?
  end

  private

    def availability_for(request)
      availabilities.find_by(date: request.date, shift: request.shift_to_i)
    end

    def create_availability!(request)
      Availability.create!(user: self, shift: request.shift, date: request.date, 
                           implicitly_created: true)
    end
    
    def create_remember_token
      self.remember_token = User.digest(User.new_secure_token)
    end
end
