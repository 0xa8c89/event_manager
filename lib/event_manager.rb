require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, "0")[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue Google::Apis::ClientError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') { |file| file.puts form_letter }
end

def clean_phone_number(number) # needs redo
  phone_number = String.new
  number.split('').each do |i|
    phone_number << i if Integer(i)
  rescue ArgumentError
    next
  end

  if phone_number.length > 11
    'bad number'
  elsif phone_number.length == 11 && phone_number[0] == '1'
    phone_number = phone_number[1..]
  elsif phone_number.length < 10 || phone_number.length > 10
    'bad number'
  elsif phone_number.length == 10
    phone_number
  end
end

def most_registrations_hour(hours_array) # redo with time objs
  registration_hours = hours_array.reduce(Hash.new(0)) do |hash, hour|
    hash[hour] += 1
    hash
  end

  registration_hours.max_by { |_key, value| value }.first
end

def day_of_the_week(time_objs)
  weekdays = time_objs.reduce(Hash.new(0)) do |hash, i|
    hash[i.strftime('%A')] += 1
    hash
  end

  weekdays.max_by { |_key, value| value }[0]
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

hours = []
time_objs = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone_number(row[:homephone])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  time = row[:regdate]
  parsed = Date._strptime(time, '%m/%d/%Y %H:%M')
  hours << parsed[:hour]

  time_objs << Time.strptime(time, '%m/%d/%Y %H:%M')
end

top_registration_hour = most_registrations_hour(hours)

top_weekday = day_of_the_week(time_objs)
