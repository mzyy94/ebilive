require 'twitter'
require 'yaml'
require 'tempfile'
require 'gruff'
require 'streamio-ffmpeg'
require 'max31855'
require 'forever'
require 'ws2812'
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

# LED configurations
led_num = config['led']['number']
led_pin = config['led']['pin']


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

def init_led(num, pin)
	led = Ws2812::Basic.new(num, pin)
	led.open
	led[(0...num)] = Ws2812::Color.new(0xff, 0xff, 0xff)
	return led
end

def set_led_color(led, r, g, b, index = nil)
	if index.nil?
		led[(0...led.count)] = Ws2812::Color.new(r, g, b)
	else
		led[index] = Ws2812::Color.new(r, g, b)
	end
end

def show_led(led, brightness = 255)
	led.brightness = brightness
	led.show
	led.close
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


	# LED control
	every 1.minutes, :at => "12:" do
		leds = init_led led_num, led_pin
		show_led leds, Time.now.min
	end

	every 1.minute, :at => "13:" do
		leds = init_led led_num, led_pin
		show_led leds, Time.now.min * 3 + 0x4e
	end

	every 2.minutes, :at => "15:" do
		leds = init_led led_num, led_pin
		for i in 0...led_num
			case i % 3
				when 0 then set_led_color leds, 0xff, 0xff, 0xff, i
				when 1 then set_led_color leds, 0xff, 0xff - Time.now.min * 4, 0xff - Time.now.min * 4, i
				when 2 then set_led_color leds, 0xff - Time.now.min * 4, 0xff - Time.now.min * 4, 0xff, i
			end
		end
		show_led leds
	end

	every 1.minute, :at => "18:" do
		leds = init_led led_num, led_pin
		for i in 0...led_num
			case i % 3
				when 0 then set_led_color leds, 0xff, 0xff, 0xff, i
				when 1 then set_led_color leds, 0xff, 0xf, 0xf, i
				when 2 then set_led_color leds, 0xf + Time.now.min * 4, 0xf + Time.now.min * 4, 0xff, i
			end
		end
		show_led leds, 0xff - Time.now.min
	end

	every 1.minute, :at => "20:" do
		leds = init_led led_num, led_pin
		for i in 0...led_num
			case i % 3
				when 0 then set_led_color leds, 0xff, 0xff, 0xff, i
				when 1 then set_led_color leds, 0xff, 0xf + Time.now.min * 4, 0xf + Time.now.min * 4, i
				when 2 then set_led_color leds, 0xff - Time.now.min * 4, 0xff - Time.now.min * 4, 0xff, i
			end
		end
		show_led leds, 0xc3
	end

	every 5.minutes, :at => "23:" do
		leds = init_led led_num, led_pin
		for i in 0...[Time.now.min/5, led_num].min
			set_led_color leds, 0, 0, 0, i
		end
		show_led leds, 0xc3
	end


	before :all do
		# HTTP Live Streaming
		vlc="vlc"
		source="v4l2://#{config['hls']['video_path']}:chroma=H264:width=#{config['hls']['width']}:height=#{config['hls']['height']}:fps=#{config['hls']['fps']}"
		destination="--sout=#standard{access=livehttp{seglen=#{config['hls']['seglen']},delsegs=#{config['hls']['delsegs']},numsegs=#{config['hls']['numsegs']},index=#{config['hls']['live_path']}/index.m3u8,index-url=live-#######.ts},mux=ts{use-key-frames},dst=#{config['hls']['live_path']}/live-#######.ts}"
		quit="vlc://quit"
		interface="-I dummy"
		pid = spawn("sudo", "-u", "pi", vlc, interface, source, quit, destination)
	end


	on_ready do
		twitter_streaming_thread = Thread.new do
			begin
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
			rescue Twitter::Error::Forbidden, Twitter::Error::Unauthorized => error
				puts "Error[#{error.code}]: #{error.message}\nCheck your token."
			rescue Twitter::Error::ClientError, Twitter::Error::ServerError, Twitter::Error::TooManyRequests => error
				puts "Error[#{error.code}]: #{error.message}\nWill retry in 10 sec."
				sleep 10
				retry
			rescue Timeout::Error, Errno::EPIPE => error
				puts "Error[#{error.code}]: #{error.message}\nWill retry in 30 sec."
				sleep 30
				retry
			rescue => error
				puts "Error[#{error.code}?]: #{error.message}"
			end
		end
	end
end
