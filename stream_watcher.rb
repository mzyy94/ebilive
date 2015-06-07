require 'twitter'
require_relative 'camera/Camera'

token = eval File.read 'token.rb'

rest = Twitter::REST::Client.new do |config|
	config.consumer_key        = token[:consumer_key]
	config.consumer_secret     = token[:consumer_secret]
	config.access_token        = token[:access_token]
	config.access_token_secret = token[:access_token_secret]
end

streaming = Twitter::Streaming::Client.new do |config|
	config.consumer_key        = token[:consumer_key]
	config.consumer_secret     = token[:consumer_secret]
	config.access_token        = token[:access_token]
	config.access_token_secret = token[:access_token_secret]
end

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
