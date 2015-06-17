require 'tempfile'
require 'tmpdir'

class Camera
	class << self
		def take_picture(width = 1280, height = 720, fps = 30)
			t = Tempfile.open(['capture', '.jpg'])
			t.binmode
			t.write `fswebcam -F 100 -r #{width}x#{height} --fps #{fps} -p YUYV -`
			return t
		end

		def record_video(width = 640, height = 480, fps = 5, duration = 8, skip = 3, color = 32)
			t = Tempfile.open(['record', '.gif'])
			Dir.mktmpdir{|dir|
				`avconv -f video4linux2 -s #{width}x#{height} -r #{fps} -b 512 -an -i /dev/video0 -ss #{skip} -t #{duration} -f image2 #{dir}/%06d.jpg`
				`convert -delay #{ 100 / fps } -resize 80% -colors #{color} -fuzz 8 #{dir}/*.jpg #{dir}/out.gif`
				t.binmode
				t.write `cat #{dir}/out.gif`
			}
			return t
		end
	end
end
