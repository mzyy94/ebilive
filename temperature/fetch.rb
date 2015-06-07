require_relative 'ADT7410'

sensor = ADT7410.new('/dev/i2c-1')

10.times do
	p sensor.fetch_temperature
	sleep(1)
end
