# $Id: modemcom.rb,v 1.28 2008/04/22 13:02:45 cth Exp $

require 'monitor'
require 'socket'
require 'http_client.rb'
require 'utils.rb'
require 'pdu.rb'

class ModemCommunicator
  attr_reader :name, :address, :port

  @@modem_names = {}
  @@modem_names.extend(MonitorMixin)

  def ModemCommunicator.add_modem(mcom)
    @@modem_names.synchronize do
      # FIXME
      raise "Duplicate modem name " + mcom.name.to_s unless @@modem_names[mcom.name].nil?
      @@modem_names[mcom.name] = mcom
    end
  end

  def initialize(cfg, logger)
    @logger = logger
    puts cfg.inspect
    @name = cfg['name'].to_s
    @address = cfg['server-address'].to_s
    @port = cfg['port'].to_s
    @pincode = cfg['pincode'].to_s
    @shutdown = false
    @to_delete = []

    if @address.nil? or @address.empty? 
      @logger.error @name + " No address specified!"
    end

    if @port.nil? or @port.empty?
      @logger.error @name + " No port specified!"
    end

    @outgoing_queue = []
    @outgoing_queue.extend(MonitorMixin)


    @http_client = HTTPClient.new(cfg['sendto'].to_s,logger)

    ModemCommunicator.add_modem(self)

    @logger.info "Modem communicator initialized"
  end

  def shutdown
    @logger.info @name + " modem comm thread received message to shutdown"
    @shutdown = true
  end

  # Queue a SMS for sending via this modem
  def send_sms(sms)
    @logger.info "Sending pdu"
    @outgoing_queue.synchronize { @outgoing_queue << sms }
  end

  def connect
        @socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
        @socket.connect(Socket.pack_sockaddr_in(@port,@address))
  end

  # Run the main loop
  def run
    @logger.info "modem comm thread for modem=" + @name + " is now running"
    error_count = 0

    loop do
      
      if @shutdown == true
        @logger.info @name + " shutting down..."
        break
      end
      
      sleep 1

      begin 
        @logger.info "Trying to connect to #{@address} : #{@port}"
        connect
        @logger.info @name + " - connected"

        authenticate unless (@pincode.nil? or @pincode.empty?)

        @logger.debug "Authenticated :-)"

        # Read incoming messages
        incoming_messages.each { |pdu| @http_client.send_http_request(SMS.create_from_pdu(pdu, @name)) }
        # Extract a message from the queue

        delete_messages

        # We only send one message per iteration. We don't the sending 
        # of messages to block recieving messages
        sms = nil
        @outgoing_queue.synchronize { sms = @outgoing_queue.shift }
        puts sms.inspect
        send_pdu(sms.to_pdu) unless sms.nil?
      rescue Exception => boomcrashbang
        error_count = error_count + 1
        @logger.error "Exception in modem communicator thread (#{name}): " + boomcrashbang
        @logger.info "modemthread " + @name + " is waiting #{error_count} seconds before trying again"
        print boomcrashbang.backtrace.join("\n")
        next
      ensure
        @socket.close
        sleep error_count
      end
      error_count = 0
    end
    @logger.info "modem " + @name + " communicator is shutting down"
  end

  def authenticate
    @logger.info @name + " authenticating.."
    cmd "AT+CPIN=" + @pincode
    expect_ok and @logger.info "modem #{name} authenticated"
    #    line = @socket.gets
    # raise "Could not authenticate for modem #{name}" unless line == "OK"
    # log.@logger.info "modem #{name} authenticated"
  end

  def send_pdu(pdu)
    # set pdu mode
    @logger.debug "!!! SENDING PDU !!!"
    cmd "AT+CMGF=0"
    expect_ok or raise "send_pdu (#{@name}): could not set PDU mode"
    # Check if modem supports SMS commands     
    cmd "AT+CSMS=0"
    expect_ok or raise "send_pdu (#{@name}): Modem doesn't support sending PDU's :-("
    # Send the PDU
    @logger.debug "sending pdu"
    cmd "AT+CMGS=" + pdu.length.to_s
    sleep 0.5
    # jumphere
    readprompt(@socket)

    write_pdu pdu
    @logger.debug "snd cmd"
    sleep 0.2

    expect_ok
  end
  
  def incoming_messages
    @to_delete = []
    @logger.info @name + " reading incoming messages"
    pdus = []
    # Tell modem to give us the messages binary encoded
    cmd "AT+CMGF=0"
    expect_ok

    [ 1, 0 ].each do |cmgl|
      cmd "AT+CMGL=#{cmgl}"

      loop do
        line = readline_block(@socket)
        @logger.debug "read line: " + line

        if line =~ /^\+CMGL:.*$/
          arr = (line.split(':'))[1].split(',')
          index, stat, none, bytes = *arr 
          @to_delete << index
          # next line contains actual messages

          line = readline_block(@socket)
          @logger.debug("pdu line:" + line)
          begin 
            pdus << PDU.new(line) unless line.nil?
          rescue Exception => pdu_exp
            @logger.error pdu_exp.inspect
            @logger.error 'PDU line was ' + (line.nil? ? "nil" : line)
          end
        elsif line == "OK" # wait for OK
          @logger.debug "GOT OK: " + line
          break
        elsif line == "ERROR"
          raise "Server responded with ERROR to the command: AT+CMGL=#{cmgl}"
        else
          @logger.debug "line was: " + line
        end
      end
    end
    return pdus
  end

  def delete_messages
    @logger.info @name + " deleting messages left on modem"
    @logger.info @name + " no message to delete." if @to_delete.empty? 
    while not @to_delete.empty? do
      index = @to_delete.shift
      cmd "AT+CMGD="+index
      begin
        expect_ok
      rescue Error => ups
        @logger.error ups + " modem #{name} could not delete message with index " + index
      end
    end
  end
  
  def write_pdu(pdu)
    sleep 0.1
    @logger.debug "writing pdu: " + pdu.encode
    @socket.write pdu.encode
    @socket.write "\026"
    @socket.flush
    sleep 0.1
  end

  def cmd(s)
    sleep 0.1
    @logger.debug "Sending command: " + s
    @socket.write s + "\r"
    @socket.flush
    sleep 0.1
  end

  def expect_ok
    @logger.debug "Expecting ok"
    loop do
      line = readline(@socket)
      @logger.debug "got: " + line
      if line =~ /OK/
        break
      elsif line =~ /ERROR/
        raise line
      end
    end
    true
  end
end
