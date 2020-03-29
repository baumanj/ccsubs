class User < ActiveRecord::Base
  # Maybe change this later
  # default_scope { where(disabled: false) }

  MAX_LOGIN_ATTEMPTS = 10

  scope :active, -> { where(disabled: false) }

  enum volunteer_type: [ 'Regular Shift', 'Alternating', 'Sub Only' ]
  enum first_day_of_week_preference: Date::DAYNAMES
  enum location: ['Northgate', 'Belltown', 'Renton']

  attr_accessor :confirmation_token
  has_secure_password

  has_many :requests, -> { extending ShiftTime::ClassMethods }
  has_many :availabilities, -> { extending ShiftTime::ClassMethods }
  has_many :default_availabilities
  has_many :on_calls, -> { extending ShiftTime::ClassMethods }
  accepts_nested_attributes_for :requests, :availabilities, :default_availabilities

  # allow_nil so that users can edit their profile w/o entering password
  validates :password, length: { minimum: 5 }, allow_nil: true
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :phone, presence: true, on: :create
  validates :volunteer_type, presence: true, on: :create
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@([a-z\d\-]+\.)+[a-z]+\z/i
  validates :email, presence: true, format: { with: VALID_EMAIL_REGEX },
    uniqueness: { case_sensitive: false }
  validates :vic, presence: true, uniqueness: true, on: :create
  validates :location, presence: true
  validate on: :update do
    requests.find_all(&:new_record?).each do |r|
      r.errors.each do |attr, msg|
        full_attr = :"requests.#{attr}"
        errors.add(full_attr, msg) if errors[full_attr].exclude? msg
      end
    end
  end

  include Gravtastic
  gravtastic :email

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

  def User.new_admin(name:, email:)
    password = SecureRandom.urlsafe_base64
    u = User.new(name: name, email: email, confirmed: true, admin: true, staff: true, password: password, password_confirmation: password)
    u.save(validate: false)
    u.confirmed = true
    u.save(validate: false)
    u
  end

  def staff_or_admin?
    staff? || admin?
  end

  def to_s
    Rails.env.development? ? "#{name} [#{id}]" : name
  end

  def phone
    cell_phone && home_phone ? "C: #{cell_phone} H: #{home_phone}" : cell_phone || home_phone
  end

  def User.digest(token)
    Digest::SHA1.hexdigest(token.to_s)
  end

  def upcoming_coverage
    Request.including_holidays.on_or_after(Date.today).fulfilled.select {|r| r.fulfilling_user == self}
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
    save!
    remember_token
  end

  def sign_out
    self.remember_token = User.digest(User.new_secure_token)
    save!(validate: false)
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
      # update_attribute(:confirmed, true)
      update(confirmed: true)
    end
  end

  # For given user U and shift S, describe the relation availability(U, S).
  # That is, U's availability for S, in terms of these categories:
  # (Higher categories preclude lower ones)
  #
  # Past: S is in the past (state of U irrelevant).
  #
  # Uninterested: U is not looking for swaps (value of S irrelevant).
  #
  # Requesting: U has a request at the same time as S.
  #
  # Subbing: U has a pending or accepted offer to cover S already.
  #
  # Free: U has specifed "yes", they can cover S.
  #
  # Busy: U has specified "no", they cannot cover S shift or they have a
  #       pending or accepted request to cover S already.
  #
  # Potential: None of the above; we have no information from U about S.
  def availability_state_for(shifttime, preloaded_requests, preloaded_availabilities)

    # raise unless requests.active.any? # XXX remove

    if shifttime.start.past?
      return :past
    # elsif requests.active.none? # These are filtered out earlier; avoid the queries
    #   return :uninterested
    elsif preloaded_requests.find {|r| r.user_id == self.id && r.shifttime_attrs == shifttime.shifttime_attrs }
      return :requesting
    end

    availability = preloaded_availabilities.find {|a| a.user_id == self.id && a.shifttime_attrs == shifttime.shifttime_attrs }
    if availability.nil? || availability.free.nil?
      return :potential
    elsif availability.request
      # We could eliminate an SQL query here if availabilities tied to pending requests were not free,
      # or if we denormalized such that availabilities had a foreign key to their requests
      return :subbing
    else
      return availability.free? ? :free : :busy
    end
  end

  def conflict_for(shifttime)
    a = availabilities.find_by_shifttime(shifttime)
    if a && !a.free?
      a
    else
      requests.find_by_shifttime(shifttime)
    end
  end

  def find_or_initialize_availability_for(request)
    availabilities.find_or_initialize_by(request.shifttime_attrs) do |new_availability|
      new_availability.assign_attributes(implicitly_created: true, free: true)
    end
  end

  # Return all the requests owned by this user which could be offered as a swap
  # for at least one of the requests in for_requests
  def offerable_swaps(for_requests=Request.active.all)
    requests.active.select do |my_request|
      (my_request.offerable_swaps & [*for_requests]).any?
    end
  end

  def requested_availabilities
    availabilities_for(receivers_availability: :free, senders_availability: :potential)
  end

  def suggested_availabilities
    availabilities_for(:potential_matches)
  end

  # We can call this three ways:
  # 1. With a named relation like :half_matches, the request list will come from
  #    the mapping of the active requests like request.half_matches.
  # 2. Like 1, but instead of a named relation, it is specified with the args
  #    that Request#match accepts.
  # 3. An existing collection of Requests.
  def availabilities_for(relation_or_requests)
    matches =
      if relation_or_requests[0].is_a? Request
        relation_or_requests
      else
        requests.matching_requests(relation_or_requests)
        # ^ need to include a newly created request here
      end

    matches.map {|r| availability_for(r) }.uniq(&:start)
  end

  def availability_for(shifttime)
    availabilities.find_or_initialize_by(shifttime.shifttime_attrs)
  end

  def default_availability_for(shifttime)
    default_availabilities.find_or_initialize_by_shifttime(shifttime)
  end

  def location_for(date)
    if date.to_date < ShiftTime::LOCATION_CHANGE_DATE
      ShiftTime::LOCATION_BEFORE
    else
      self.location
    end
  end

  def location_matches(request)
    self.location_for(request.date) == request.location
  end

  def self.like(conditions)
    conditions.reduce(self.all) do |relation, (column, value)|
      relation.where("#{connection.quote_column_name(column)} LIKE ?", "%#{value}%")
    end
  end

  def self.with_active_requests_check
    fast = with_active_requests.to_a.sort
    slow = with_active_requests_slow.sort
    puts fast == slow
  end

  def self.with_active_requests_slow
    User.select {|u| u.requests.any? {|r| r.active_slow? } }
  end

  def self.with_active_requests
    joins(:requests).merge(Request.unscoped.where(type: 'Request').active).distinct
  end

  def self.check_phone
    users_without_phone = User.where(home_phone: nil, cell_phone: nil, disabled: false).where.not(volunteer_type: nil)
    if users_without_phone.any?
      UserMailer.alert("Users with no phone:\n#{users_without_phone.pluck(:name).join('\n')}").deliver_now
    end
  end

  private

    def create_remember_token
      self.remember_token = User.digest(User.new_secure_token)
    end
end
