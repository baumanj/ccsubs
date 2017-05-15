desc "This task is for printing on-off stats type stuff"
task :on_call_stats => :environment do
  months = [Date.today, Date.today.next_month, Date.today.next_month.next_month].map(&:all_month)
  months.each do |month|
    next if month.first < OnCall::FIRST_VALID_DATE
    puts "#{month.first.strftime('%b')}: #{OnCall.where(date: month).count}/#{month.count * OnCall.shifts.count}"
  end
end

task :on_call_histogram => :environment do
  month = Date.current.next_month
  month_name = month.strftime('%B')
  puts "Signups by day for #{month_name}"

  next_month_on_calls = OnCall.where(date: month.all_month)
  signups_by_date = next_month_on_calls.group_by {|o| o.created_at.to_date }
  signup_date_range = (signups_by_date.keys.first)..(Date.current)
  signup_date_range.each do |date|
    puts "%2d: #{'*' * signups_by_date.fetch(date, []).length}" % [date.day]
  end

  signups = next_month_on_calls.size
  slots = month.all_month.count * OnCall.shifts.count
  puts "Total: #{signups}/#{slots} (#{signups * 100 / slots}%)"

  average = signups.to_f / signup_date_range.count
  puts "%.1f average signups per day" % [average]

  days_til_first = month.beginning_of_month - Date.current
  total_by_first = signups + (days_til_first * average)
  days_til_last = month.end_of_month - Date.current
  total_by_last = signups + (days_til_last * average)

  puts "Projected signups by #{month_name} 1:  #{total_by_first.round}"
  puts "Projected signups by #{month_name} #{month.end_of_month.day}: #{total_by_last.round}"
end