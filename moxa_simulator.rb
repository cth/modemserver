# The MoxaSimulator is a TCP server that simulates a moxa box with
# a number of modems connected to it

require 'socket'
require 'utils.rb'

class SimulatedModem
  def initialize(port)
    @port = port
  end

  def run
    puts "Simlated modem running on port #{@port}. Waiting for connections"

    serv = TCPServer.new(@port)
    begin
      sock, client_addr = serv.accept
    rescue Errno::EAGAIN, Errno::ECONNABORTED, Errno::EPROTO, Errno::EINTR
      IO.select([serv])
      retry
    end

    puts "Client connected from #{client_addr.to_s}. Waiting for commands."

    loop do
      begin
        puts "waiting for commands:"
        req = readline(sock)
        puts req
        resp = process_request(req)
        sock.write resp + "\r"
        puts resp
      rescue Exception => e
        puts e.to_s
        sleep 10
      end
    end
  end

  def process_request(req)
    if req =~ /AT\+CPIN=\d\d\d\d/
      "OK"
    elsif req =~ /AT\+CMGF=\d/
      "OK"
    elsif req =~ /AT\+CMGL=\d/
      "OK"
    elsif req =~ /AT\+CMGD=\d+/
      "OK"
    else
      "ERROR"
    end
  end
end

class MoxaSimulator
  def initialize(num_modems = 2, start_port = 4001)
    @number_of_modems = num_modems
    @start_port = start_port
  end

  def run
    puts "MoxaSimulator.run"
    threads = []
    0.upto @number_of_modems-1 do |m|
      port = m+@start_port
      puts "port is #{port.to_s}"
      modem = SimulatedModem.new(m+@start_port)
      threads << Thread.new { modem.run }
    end

    threads.each { |t| t.join }
  end
end

MoxaSimulator.new.run
