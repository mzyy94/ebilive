#include <ruby.h>

#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/spi/spidev.h>

#define SPI_DEVICE    "/dev/spidev0.0"
#define SPI_SPEED     4000000
#define SPI_BITS      8

struct spidev {
	int fd;
	const char* path;
	unsigned int clock;
	unsigned char mode;
	unsigned char bits;
};

VALUE cMAX31855;


VALUE wMAX31855_initialize(int argc, VALUE *argv, VALUE self)
{
	struct spidev *device;

	Data_Get_Struct(self, struct spidev, device);

	device->path = argc < 1 ? SPI_DEVICE : StringValuePtr(argv[0]);
	device->clock = argc < 2 ? SPI_SPEED : NUM2INT(argv[1]);
	device->mode = SPI_MODE_0;
	device->bits = SPI_BITS;

	// Open SPI device
	if ((device->fd = open(device->path, O_RDWR)) < 0) {
		rb_raise(rb_eArgError, "Cannot open %s", device->path);
	}

	// Set SPI mode
	if (ioctl(device->fd, SPI_IOC_WR_MODE, &device->mode) < 0) {
		close(device->fd);
		rb_raise(rb_eSystemCallError, "Cannot set WR_MODE to %d", device->mode);
	}
	if (ioctl(device->fd, SPI_IOC_RD_MODE, &device->mode) < 0) {
		close(device->fd);
		rb_raise(rb_eSystemCallError, "Cannot set RD_MODE to %d", device->mode);
	}

	// Set SPI bits per word
	if (ioctl(device->fd, SPI_IOC_WR_BITS_PER_WORD, &device->bits) < 0) {
		close(device->fd);
		rb_raise(rb_eSystemCallError, "Cannot set WR_BITS_PER_WORD to %d", device->bits);
	}

	if (ioctl(device->fd, SPI_IOC_RD_BITS_PER_WORD, &device->bits) < 0) {
		close(device->fd);
		rb_raise(rb_eSystemCallError, "Cannot set RD_BITS_PER_WORD to %d", device->bits);
	}
	
	return Qnil;
}


unsigned char* receiveData(struct spidev* device, unsigned int len)
{
	unsigned char *send = (unsigned char *)malloc(len * sizeof(unsigned char));
	unsigned char *recv = (unsigned char *)malloc(len * sizeof(unsigned char));
	struct spi_ioc_transfer tr = {
		.tx_buf        = (unsigned int)send,
		.rx_buf        = (unsigned int)recv,
		.len           = len,
		.speed_hz      = device->clock,
		.delay_usecs   = 0,
		.bits_per_word = device->bits,
		.cs_change     = 0,
		.pad           = 0
	};

	memset(send, 0, len);
	memset(recv, 0, len);

	// Send SPI message
	if (ioctl(device->fd, SPI_IOC_MESSAGE(1), &tr) < 0) {
		rb_raise(rb_eSystemCallError, "Cannot send SPI message");
	}

	return recv;
}


VALUE wMAX31855_fetch(VALUE self)
{
	struct spidev *device;
	unsigned char* recv;
	unsigned int thermocouple_raw;
	unsigned int internal_raw;
	double thermocouple, internal;

	Data_Get_Struct(self, struct spidev, device);

	recv = receiveData(device, 4);

	thermocouple_raw = recv[0] << 8;
	thermocouple_raw |= recv[1];
	internal_raw = recv[2] << 8;
	internal_raw |= recv[3];

	if (thermocouple_raw & 0x0001) { // Error bit
		char message[128];
		memset(message, 0, 128);
		if (internal_raw & 0x0004) {
			strcat(message, "Short to Vcc,");
		}
		if (internal_raw & 0x0002) {
			strcat(message, "Short to GND,");
		}
		if (internal_raw & 0x0001) {
			strcat(message, "Open Circuit");
		}    
		rb_raise(rb_eStandardError, message);
		return Qnil;
	} else {
		if ((thermocouple_raw & 0x8000) == 0) { // above 0 Degrees Celsius 
			thermocouple = (thermocouple_raw >> 2) * 0.25;
		} else { // below zero
			thermocouple = (((~thermocouple_raw & 0xffff) >> 2) + 1)  * -0.25;
		}

		if ((internal_raw & 0x8000) == 0) { // above 0 Degrees Celsius
			internal = (internal_raw >> 4) * 0.0625;
		} else { // below zero
			internal = (((~internal_raw & 0xffff) >> 4) + 1) * -0.0625;
		}

		return rb_ary_new3(2, rb_float_new(thermocouple), rb_float_new(internal));
	}
}


void wMAX31855_free(struct spidev *p)
{
	close(p->fd);
	ruby_xfree(p);
}
 
static VALUE wMAX31855_alloc(VALUE klass)
{
	struct spidev *p = ALLOC(struct spidev);
        return Data_Wrap_Struct(klass, 0, wMAX31855_free, p);
}


void Init_MAX31855()
{
	cMAX31855 = rb_define_class("MAX31855", rb_cObject);

	rb_define_alloc_func(cMAX31855, wMAX31855_alloc);
	rb_define_private_method(cMAX31855, "initialize", RUBY_METHOD_FUNC(wMAX31855_initialize), -1);
	rb_define_method(cMAX31855, "fetch", RUBY_METHOD_FUNC(wMAX31855_fetch), 0);
}
