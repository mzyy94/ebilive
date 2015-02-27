require 'i2c'

class ADT7410

	def initialize(path, address = 0x48)
		@device = I2C.create(path)
		@address = address
	end

	def fetch_temperature
		data = @device.read(@address, 0x02)
		temp_h, temp_l = data.bytes.to_a

		temp = ((temp_h << 8) | temp_l) >> 3

		return temp * 0.0625
	end

end
