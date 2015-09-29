class User < ActiveRecord::Base

  MAX_LOGIN_ATTEMPTS = 10

  attr_accessor :confirmation_token
  has_secure_password

  has_many :requests, -> { extending ShiftTime::ClassMethods }
  has_many :availabilities, -> { extending ShiftTime::ClassMethods }
  accepts_nested_attributes_for :requests, :availabilities

  # allow_nil so that users can edit their profile w/o entering password
  validates :password, length: { minimum: 5 }, allow_nil: true
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@([a-z\d\-]+\.)+[a-z]+\z/i
  validates :email, presence: true, format: { with: VALID_EMAIL_REGEX },
    uniqueness: { case_sensitive: false }
  validates :vic, presence: true, uniqueness: true, on: :create
  validate on: :update do
    requests.find_all(&:new_record?).each do |r|
      r.no_availabilities_conflicts(availabilities)
      r.errors.each do |attr, msg|
        full_attr = :"requests.#{attr}"
        errors.add(full_attr, msg) if errors[full_attr].exclude? msg
      end
    end
  end

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
    save!
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
  def availability_state_for(shifttime, looking_for_swaps: requests.active.any?)

    if shifttime.start.past?
      return :past
    elsif !looking_for_swaps && requests.active.none?
      return :uninterested
    elsif requests.find_by_shifttime(shifttime)
      return :requesting
    end

    availability = availabilities.find_by_shifttime(shifttime)
    if availability.nil? || availability.free.nil?
      return :potential
    elsif availability.request
        return :subbing
    else
      return availability.free? ? :free : :busy
    end
  end

  # True iff positively available; false if unknown
  def available?(shifttime)
    availability_state_for(shifttime) == :free
  end

  # True iff positively unavailable; false if unknown
  def unavailable?(shifttime)
    !available?(shifttime) && availability_state_for(shifttime) != :potential
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

  def offerable_swaps(for_requests=requests.active.all)
    [*for_requests].flat_map(&:offerable_swaps)
  end

  def requested_availabilities
    puts "******** requested_availabilities for #{self}"
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
        # Would work with all; limiting to active is an optimization
        puts "******** calling matching_requests for #{self}'s #{requests.active.count} active requests"
        requests.active.matching_requests(relation_or_requests)
        # ^ need to include a newly created request here
      end
    puts "******** mapping #{self}'s #{matches.count} matches to availabilities"
    matches.map {|r| availability_for(r) }.uniq(&:start)
  end

  def pending_offers
    requests.select(&:pending?)
  end

  def availability_for(shifttime)
    puts "******** availability_for for #{shifttime} for #{self}"
    availabilities.find_or_initialize_by(shifttime.shifttime_attrs)
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
    joins(:requests).merge(Request.unscoped.active).distinct
  end

  private

    def create_remember_token
      self.remember_token = User.digest(User.new_secure_token)
    end
end
