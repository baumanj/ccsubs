class User < ActiveRecord::Base
  attr_accessor :confirmation_token
  has_many :requests
  has_many :fulfilled_requests, class_name: "Request", foreign_key: "fulfilling_user_id"
  has_many :availabilities
  has_many :unavailabilities
  accepts_nested_attributes_for :availabilities
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
    Rails.env.development? ? "#{name} [#{id}]" : name
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

  def unavailable?(request)
    a = availabilities.find_by_shifttime(request)
    (a && a.request != nil) || unavailabilities.find_by_shifttime(request)
  end

  def available?(request)
    a = availabilities.find_by_shifttime(request)
    a && a.request.nil?
  end

  def availability_for!(request)
    unless unavailable?(request)
      availabilities.find_by_shifttime(request) || create_availability!(request)
    end
  end

  def open_requests_matching_availability
    Request.all_seeking_offers.select {|r| available?(r) }
  end

  def swap_candidates
    open_requests.select do |my_req|
      others_reqs = my_req.swap_candidates.flat_map {|_, reqs| reqs }
      others_reqs.any? {|r| available?(r) }
    end
  end
  
  # Return the array of requests whose owners have availability matching the user's requests
  # but for whose requests the user's availability is unknown. That is, potential matches.
  def unknown_availability
    users_with_open_requests = Request.all_seeking_offers.map &:user
    users_with_availability_matching_my_requests = users_with_open_requests.select do |u|
      u.open_availabilities.find_index do |a|
        open_requests.find_index {|r| r.start == a.start }
      end
    end
    users_with_availability_matching_my_requests.flat_map do |u|
      u.open_requests.reject {|r| availability_known?(r) }
    end.map {|r| Availability.new(date: r.date, shift: r.shift) }.uniq {|a| a.start }
  end

  def availability_known?(shift)
    [availabilities, unavailabilities, requests].reduce(false) do |found, x|
      found || x.exists?(date: shift.date, shift: shift.shift_to_i)
    end
  end

  def suggested_availabilities
    unique_shift_requests = Request.all_seeking_offers.uniq {|r| r.start }
    unique_shift_requests.map do |r|
      unless r.user == self || availability_known?(r)
        Availability.new(date: r.date, shift: r.shift)
      end
    end.compact
  end

  def pending_offers
    Request.pending_requests(id)
  end

  def pending_offers?
    pending_offers.any?
  end

  private

    def create_availability!(request)
      Availability.create!(user: self, shift: request.shift, date: request.date, 
                           implicitly_created: true)
    end
    
    def create_remember_token
      self.remember_token = User.digest(User.new_secure_token)
    end
end
