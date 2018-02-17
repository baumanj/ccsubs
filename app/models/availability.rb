class Availability < ActiveRecord::Base
  include ShiftTime
  default_scope { order(:date, :shift) }

  belongs_to :user
  has_one :request
  
  enum shift: ShiftTime::SHIFT_NAMES
  attr_accessor :from_default # If this instance was populated from a DefaultAvailability

  validates :user, presence: true
  validates_with ShiftTimeValidator
  validate do
    if user.requests.exists?(shifttime_attrs)
      errors.add(:shift, "can't be the same as your own existing request")
    end

    if free?
      if request && request.fulfilled? == free?
        errors.add(:request, "must be #{free? ? "not be" : "be"} fulfilled if free? is #{free?}")
      elsif user.on_calls.find_by(shifttime_attrs)
        errors.add(:free, "can't be true if you're on call for that shift (#{self}")
      end
    elsif free.nil?
      errors.add(:free, "must be indicated 'Yes' or 'No'")
    end

    # if (s = user.availability_state_for(self)) != :potential
    #   errors.add(:state, "cannot be #{s} before creating availability")
    # end
  end

  # Nofity other users about this availability we've just added
  # on update to free as well?
  after_save if: :active? do
    future_requests = Request.future.to_a
    future_availabilities = Availability.future.to_a
    Request.active.where_shifttime(self).each do |others_req|
      # This other person (Bob) wants to know about two situations:
      # 1. Bob can send a swap reqest for one or more of self's requests IF
      #    Bob is available. Right now, we only know Bob is potential
      #    :ask_sender_match
      # 2. Bob can DEFINITELY send a swap request for one or more or self's
      #    requests because they're both available. In fact, self will likely
      #    have already send one. This is more specific and should come first.
      #    :full_match

      # We want to categorize matches for Bob as the sender
      matching_requests = others_req.categorize_matches(self.user, [:full_match, :ask_sender_match],
                                                        future_requests, future_availabilities)
      UserMailer.active_user = user # For preview mode
      if matching_requests[:full_match].any?
          # Just let Bob know; self.user will be notified on their dashboard
          UserMailer.notify_full_matches(others_req, matching_requests[:full_match]).deliver_now
      elsif matching_requests[:ask_sender_match].any?
        UserMailer.notify_potential_matches(others_req, matching_requests[:ask_sender_match]).deliver_now
      end
    end
    # v2: only send a notification email if there have been new matching availabilities
    # added since the last time the user visited the site (or maybe 1/day)
  end

  before_destroy do
    if locked?
      errors.add(:availability, "Can not be deleted while tied to a request")
      false
    end
  end

  def self.destroy_oldest_past
    Rails.application.eager_load! # probably only necessary in dev
    record_counts = Hash[ActiveRecord::Base.descendants.map {|table| [table.name, table.count] }]
    total = record_counts.values.reduce(&:+)
    puts "Record counts:\n#{record_counts}\nTotal: #{total}"

    # Heroku limit is 10,000 rows, start deleting when we get within 10% of the max
    num_to_delete = total - 9000

    if num_to_delete > 0
      destroyed = Availability.past.reorder(:created_at).limit(num_to_delete).destroy_all
      puts "Destroyed #{destroyed.count} oldest availabilities"
      num_to_delete -= destroyed.count
    else
      puts "Only #{Availability.count} availabilities; no need to destroy any"
    end

    if num_to_delete > 0
      destroyed = DefaultAvailability.joins(:user).where(users: {disabled: true}).limit(num_to_delete).destroy_all
      puts "Destroyed #{destroyed.count} default availabilities (of disabled users)"
      num_to_delete -= destroyed.count
    else
      puts "No need to destroy any default availabilities"
    end

    if num_to_delete > 0
      UserMailer.alert("Wanted to delete #{num_to_delete} more records\n#{record_counts}\nTotal: #{total}").deliver_now
    end
  end

  # def self.with_includes
  #   # does left outer join
  #   # SELECT COUNT(DISTINCT "users"."id") FROM "users" LEFT OUTER JOIN "requests" ON "requests"."user_id" = "users"."id" WHERE ("requests"."id" IS NOT NULL)
  #   User.includes(:requests).where.not("requests.id" => nil)
  #   User.includes(:requests).where("requests.state" => 0).where.not("requests.id" => nil)
  # end

  def self.active
    # It seems like the combination of these two should work, but it doesn't
    # due to referencing the requests table twice. I can't seem to get a
    # subquery to work with ActiveRecord::QueryMethods#from
    joins(:user).merge(User.with_active_requests).
      future.where(free: true).
      includes(:request).where(requests: {state: Request.states[:seeking_offers]})
      # includes(:request).where(requests: {availability_id: nil})
      # select {|a| a.request.nil? } # < would like to replace with below
  end

  def self.active_slow
    # It seems like the combination of these two should work, but it doesn't
    # due to referencing the requests table twice. I can't seem to get a
    # subquery to work with ActiveRecord::QueryMethods#from
    joins(:user).merge(User.with_active_requests)
      .future.where(free: true)
      .select {|a| a.request.nil? } # < would like to replace with below
  end

  def self.free
    where(free: true)
  end

  def active_slow?
    start.future? && free? && request.nil? && user.requests.any? {|r| r.active_slow? }
  end

  def locked?
    !request.nil?
  end

  # others are free for any of this user's requests
  def match?(my_requests = user.requests.active)
    Request.where_shifttime(self).map(&:user).uniq.any? do |other|
      [*my_requests].any? {|r| other.availability_state_for(r) == :free }
    end
  end
end
