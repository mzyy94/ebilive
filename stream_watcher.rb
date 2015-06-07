require 'twitter'
require 'yaml'
require_relative 'camera/Camera'

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

my_source = '<a href="https://github.com/mzyy94/holoholo/" rel="nofollow">えびかんさつ</a>'

words = /(えび|エビ|海老|蝦|🍤")/
text = 'えびだよ'
picture = /(画像|絵|写真)/
video = /(動画|見たい|みたい)/

streaming.user(with: "user") do |tweet|
	if tweet.is_a?(Twitter::Tweet)
		if tweet.text =~ words and tweet.source != my_source
			if tweet.text =~ video
				file = Camera.record_video
				rest.update_with_media("@#{tweet.user.screen_name} #{text}", file, {in_reply_to_status: tweet})
				file.close
			end

			if tweet.text =~ picture
				file = Camera.take_picture
				rest.update_with_media("@#{tweet.user.screen_name} #{text}", file, {in_reply_to_status: tweet})
				file.close
			end
		end
	end
end
