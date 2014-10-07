class Request < ActiveRecord::Base
  belongs_to :user
  # TODO: Validate start/end time
end
