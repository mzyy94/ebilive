require_relative 'MAX31855'

sensor = MAX31855.new 

10.times do
	thermo, inter = sensor.fetch
	p thermo
	p inter
	sleep(1)
end
