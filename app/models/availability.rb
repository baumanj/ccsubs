class Availability < ActiveRecord::Base
  include ShiftTime
  default_scope { order(:date, :shift) }

  belongs_to :user
  has_one :request
  
  enum shift: ShiftTime::SHIFT_NAMES

  validates :user, presence: true
  validates_with ShiftTimeValidator

  attr_reader :create # for the checkbox tag

  def initialize(attributes = nil, options = {})
    @create = attributes.delete(:create) == "1" if attributes
    super
  end

  def tentative?
    request && !request.fulfilled?
  end

  def locked?
    request != nil
  end
end
