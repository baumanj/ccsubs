# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

require 'csv'
volunteers = CSV.read("db/volunteers.csv")
header = volunteers.shift
index = {}
header.each_with_index do |h, i|
  index[h] = i
end
volunteers.each do |v|
  name = v[index['Name']]
  vic = v[index['VIC Number']]
  email = v[index['Email']]
  User.create(vic: vic, password: vic, password_confirmation: vic, name: name,
              email: email)
end
