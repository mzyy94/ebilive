require 'twitter'
require_relative 'camera/Camera'

rest = Twitter::REST::Client.new do |config|
	config.consumer_key        = "2XQPZbKrAUUPPPP0X8KeInvJ1"
	config.consumer_secret     = "0hLCvX99Or68esqWnwBxhGnTyVa9H5QXYNqJGVORn8kG3Ri5VM"
	config.access_token        = "109758782-llplQD2XIIvJJBO5nbH7qryASIRTdL7HtX9xsImc"
	config.access_token_secret = "Sa3jvEPxQKhRNvscXR6CUoA0PKQJXhwiOCMsz7W7ydozx"
end

credentials = rest.credentials

streaming = Twitter::Streaming::Client.new do |config|
	config.consumer_key        = credentials[:consumer_key]
	config.consumer_secret     = credentials[:consumer_secret]
	config.access_token        = credentials[:token]
	config.access_token_secret = credentials[:token_secret]
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
