require 'twitter'
require 'yaml'
require 'tempfile'
require 'gruff'
require 'streamio-ffmpeg'
require 'max31855'
require 'forever'
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
thermo_sensor = Max31855.new
temp_sensor = ADT7410.new

# Temperature logging variable
temperature_log = {'date' => [], 'temp' => [], 'thermo' => [], 'inter' => []}

# FFMpeg configuration
FFMPEG::Transcoder.timeout = 10

# Mutex to lock
mutex = Mutex.new


## Some utilities

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

def get_newest_video_path(live_path)
	playlist = File.join live_path, "index.m3u8"
	last_file = ""
	File.open playlist do |file|
		file.each_line do |line|
			last_file = line.strip unless line[0] == '#'
		end
	end

	video_path = File.join(live_path, last_file)
	return video_path
end

def get_recorded_video(live_path)
	movie = FFMPEG::Movie.new get_newest_video_path(live_path)
	t = Tempfile.open(['video', '.mp4'])
	movie.transcode t.path, "-vcodec copy -an" if movie.valid?
	return t
end

def get_screenshot(live_path)
	movie = FFMPEG::Movie.new get_newest_video_path(live_path)

	t = Tempfile.open(['screenshot', '.png'])
	movie.screenshot t.path if movie.valid?
	return t
end

Forever.run do

	# Temperature logging
	every 1.minute do
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
	end


	before :all do
		# HTTP Live Streaming
		vlc="vlc"
		source="v4l2://#{config['hls']['video_path']}:chroma=H264:width=#{config['hls']['width']}:height=#{config['hls']['height']}:fps=#{config['hls']['fps']}"
		destination="--sout=#standard{access=livehttp{seglen=#{config['hls']['seglen']},delsegs=#{config['hls']['delsegs']},numsegs=#{config['hls']['numsegs']},index=index.m3u8,index-url=live-#######.ts},mux=ts{use-key-frames},dst=live-#######.ts}"
		quit="vlc://quit"
		interface="-I dummy"
		pid = spawn(vlc, interface, source, quit, destination, :err=>"/dev/null", :chdir=>config['hls']['live_path'])
	end


	on_ready do
		twitter_streaming_thread = Thread.new do
			streaming.user(with: "user") do |tweet|
				if tweet.is_a?(Twitter::Tweet)
					if tweet.text =~ words
						if tweet.text =~ video
							#NOTE:this feature is effective with modified version of twitter-gem
							# See https://github.com/mzyy94/twitter/tree/video-upload-feature
							file = get_recorded_video config['hls']['live_path']
							rest.update_with_media("@#{tweet.user.screen_name} #{message}", file, {in_reply_to_status: tweet})
							file.close
						end

						if tweet.text =~ picture
							file = get_screenshot config['hls']['live_path']
							rest.update_with_media("@#{tweet.user.screen_name} #{message}", file, {in_reply_to_status: tweet})
							file.close
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
	end
end
