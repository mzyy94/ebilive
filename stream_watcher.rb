require 'twitter'
require 'yaml'
require_relative 'camera/Camera'
require_relative 'sensors/thermocouple/MAX31855'
require_relative 'sensors/temperature/ADT7410'

config = YAML.load_file 'config.yml'

rest = Twitter::REST::Client.new(
	consumer_key:        config['twitter']['consumer_key'],
	consumer_secret:     config['twitter']['consumer_secret'],
	access_token:        config['twitter']['access_token'],
	access_token_secret: config['twitter']['access_token_secret'],
)

streaming = Twitter::Streaming::Client.new(
	consumer_key:        config['twitter']['consumer_key'],
	consumer_secret:     config['twitter']['consumer_secret'],
	access_token:        config['twitter']['access_token'],
	access_token_secret: config['twitter']['access_token_secret'],
)

# Timeline search regexps
words = Regexp.new "(" + config['search']['trigger'].split(',').join('|') + ")"
temperature = Regexp.new "(" + config['search']['temperature'].split(',').join('|') + ")"
picture = Regexp.new "(" + config['search']['picture'].split(',').join('|') + ")"
video = Regexp.new "(" + config['search']['video'].split(',').join('|') + ")"

# Reply message
message = config['response']['message']
temperature_format = config['response']['temperature']


# Setup sensors
thermo_sensor = MAX31855.new
temp_sensor = ADT7410.new

streaming_thread = Thread.new do
	streaming.user(with: "user") do |tweet|
		if tweet.is_a?(Twitter::Tweet)
			if tweet.text =~ words
				if tweet.text =~ video
					file = Camera.record_video
					rest.update_with_media("@#{tweet.user.screen_name} #{message}", file, {in_reply_to_status: tweet})
					file.close
				end

				if tweet.text =~ picture
					file = Camera.take_picture
					rest.update_with_media("@#{tweet.user.screen_name} #{message}", file, {in_reply_to_status: tweet})
					file.close
				end

				if tweet.text =~ temperature
					now = DateTime.now.to_s
					thermo, inter = thermo_sensor.fetch
					temp = temp_sensor.fetch
					text = temperature_format.sub('#now', now).sub('#temp', temp.to_s).sub('#thermo', thermo.to_s).sub('#inter', inter.to_s)
					rest.update("@#{tweet.user.screen_name} #{text}", {in_reply_to_status: tweet})
				end
			end
		end
	end
end

puts 'Start.'

streaming_thread.join
