desc "This task is for printing on-off stats type stuff"
task :on_call_stats => :environment do
  months = [Date.today, Date.today.next_month, Date.today.next_month.next_month].map(&:all_month)
  months.each do |month|
    next if month.first < OnCall::FIRST_VALID_DATE
    puts "#{month.first.strftime('%b')}: #{OnCall.where(date: month).count}/#{month.count * OnCall.shifts.count}"
  end
end
