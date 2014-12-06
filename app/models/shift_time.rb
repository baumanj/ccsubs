module ShiftTime
  
  SHIFT_NAMES = [ :'8-12:30', :'12:30-5', :'5-9', :'9-1' ]
  DATE_FORMAT = "%A, %B %e"
  
  def start
    if date && shift
      h, m = shift.split("-").first.split(":").map(&:to_i)
      date + h.hours + (m.nil? ? 0 : m.minutes)
    end
  end
  
  def to_s
    "#{date.strftime(DATE_FORMAT)}, #{shift}"
  end
end