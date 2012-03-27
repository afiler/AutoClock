require "rubygems"
require "serialport"

port_str = "/dev/tty.usbserial-A50058WQ"
baud_rate = 9600
data_bits = 8
stop_bits = 1
parity = SerialPort::NONE

sp = SerialPort.new(port_str, baud_rate, data_bits, stop_bits, parity)
sleep 2 # Arduino boot time
#while true do
#  printf("%s", sp.getc)
#  sleep 1
#end

t = Time.now
sp.puts "T%d" % (t + t.utc_offset).to_i

sp.close

