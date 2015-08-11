module ShiftTime
  
  SHIFT_NAMES = [ :'8-12:30', :'12:30-5', :'5-9', :'9-1' ]
  DATE_FORMAT = "%A, %B %e"
  
  def start
    if date && shift
      case shift
      when '8-12:30'
        date + 8.hours
      when'12:30-5'
        date + 12.hours + 30.minutes
      when '5-9'
        date + (12 + 5).hours
      when '9-1'
        date + (12 + 9).hours
      end
    end
  end

  def to_s
    "#{date.strftime(DATE_FORMAT)}, #{shift}"
  end
  
  # Enums kinda suck, we need their integer value in query contexts
  # https://hackhands.com/ruby-on-enums-queries-and-rails-4-1/
  def shift_to_i
    self.class.shifts[shift]
  end
end