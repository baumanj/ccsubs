class Request < ActiveRecord::Base
  belongs_to :user
  validates :start, presence: true
  validates :user, presence: true
  # TODO: Validate start/end time

  SHIFTS = { '8-12:30' => 8, '12:30-5' => 12, '5-9' => 17, '9-1' => 21 }

  def shift
    start.hour if start
  end

  def shift=(val)
    self.start = start - start.hour.hours + val.to_i.hours
  end

end
