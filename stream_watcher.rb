require 'twitter'

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

streaming.user(with: "user") do |tweet|
	if tweet.is_a?(Twitter::Tweet)
		if tweet.text =~ words and tweet.source != my_source
			rest.update("@#{tweet.user.screen_name} #{text}", {in_reply_to_status: tweet})
		end
	end
end
