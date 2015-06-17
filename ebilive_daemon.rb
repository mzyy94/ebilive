require 'twitter'
require 'yaml'
require 'tempfile'
require 'gruff'
require_relative 'lib/sensors/thermocouple/MAX31855'
require_relative 'lib/sensors/temperature/ADT7410'

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

# Temperature logging variable
temperature_log = {'date' => [], 'temp' => [], 'thermo' => [], 'inter' => []}

# Mutex to lock
mutex = Mutex.new

temperature_collecting_thread = Thread.new do
	loop do
		begin
			mutex.lock
			temperature_log['date'].push DateTime.now.strftime('%H:%M:%S')
			thermo, inter = thermo_sensor.fetch
			temperature_log['thermo'].push thermo
			temperature_log['inter'].push inter
			temperature_log['temp'].push temp_sensor.fetch
			if temperature_log['date'].length > 60
				temperature_log['date'].shift
				temperature_log['thermo'].shift
				temperature_log['inter'].shift
				temperature_log['temp'].shift
			end
		ensure
			mutex.unlock
		end
		sleep 60
	end
end

def generate_temperature_graph(data)
	g = Gruff::Line.new
	g.title = "Ebilive temperature"
	g.data "Water temperature", data['thermo']
	g.data "Air temperature", data['temp']
	g.data "Thermocouple internals", data['inter']

	g.labels = {0 => data['date'].first, data['date'].length - 1 => data['date'].last}

	t = Tempfile.open(['graph', '.png'])
	g.write t.path
	return t
end


# HTTP Live Streaming
vlc="vlc"
source="v4l2://#{config['hls']['video_path']}:chroma=H264:width=#{config['hls']['width']}:height=#{config['hls']['height']}:fps=#{config['hls']['fps']}"
destination="--sout=#standard{access=livehttp{seglen=#{config['hls']['seglen']},delsegs=#{config['hls']['delsegs']},numsegs=#{config['hls']['numsegs']},index=index.m3u8,index-url=live-#######.ts},mux=ts{use-key-frames},dst=live-#######.ts}"
quit="vlc://quit"
interface="-I dummy"
pid = spawn(vlc, interface, source, quit, destination, :err=>"/dev/null", :chdir=>config['hls']['live_path'])


streaming_thread = Thread.new do
	streaming.user(with: "user") do |tweet|
		if tweet.is_a?(Twitter::Tweet)
			if tweet.text =~ words
				if tweet.text =~ video
					#NOTE: currently disabled this function
					#rest.update_with_media("@#{tweet.user.screen_name} #{message}", file, {in_reply_to_status: tweet})
				end

				if tweet.text =~ picture
					#NOTE: currently disabled this function
					#rest.update_with_media("@#{tweet.user.screen_name} #{message}", file, {in_reply_to_status: tweet})
				end

				if tweet.text =~ temperature
					now = DateTime.now.to_s
					thermo, inter = thermo_sensor.fetch
					temp = temp_sensor.fetch
					text = temperature_format.sub('#now', now).sub('#temp', temp.to_s).sub('#thermo', thermo.to_s).sub('#inter', inter.to_s)
					begin
						mutex.lock
						file = generate_temperature_graph temperature_log
					ensure
						mutex.unlock
					end
					rest.update_with_media("@#{tweet.user.screen_name} #{text}", file, {in_reply_to_status: tweet})
					file.close
				end
			end
		end
	end
end

puts 'Start.'

temperature_collecting_thread.join
streaming_thread.join