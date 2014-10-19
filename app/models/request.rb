class Request < ActiveRecord::Base
  belongs_to :user
  validates :start, presence: true
  validates :user, presence: true
  # TODO: Validate start/end time
end
