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
  puts "Signups by day for #{month.strftime('%B')}"
  next_month_on_calls = OnCall.where(date: month.all_month)
  signups_by_day = next_month_on_calls.group_by {|o| o.created_at.day }
  signups_by_day.each {|k, v| puts "%2d: #{'*' * v.length}" % [k] }
  puts "Total: #{next_month_on_calls.count}"
end