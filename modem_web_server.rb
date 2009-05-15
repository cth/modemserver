require 'webrick'
require 'SMS.rb'
include WEBrick


# The modem servlet responds to request to send a message:
# It adds the message to the modem communicator threads 
# queue.
class ModemServlet < HTTPServlet::AbstractServlet
  attr_accessor :mountpoint


  def initialize(server, modem_communicator)
    super(server)
    @modem_communicator, @mountpoint = modem_communicator, @modem_communicator.name
  end
  
  
  def do_GET(req, res)
    errors, res.body = [], ""
    @logger.info "http query params: " + req.query.inspect + "\n" unless req.query['debug'].nil?
    
    sms = SMS.new(req.query['message'].to_s, @modem_communicator.name, req.query['to'].to_s)
    
    if (sms.message.nil? or sms.message.empty?)
      errors << "empty message"
    end
    
    if (sms.to.nil? or sms.to.empty?)
      errors << "empty to field"
    end
    
    # Attempt to add to queue:
    begin 
      @modem_communicator.send_sms(sms) if errors.empty?
    rescue Exception => e
      @logger.error e.to_s
      errors << e.to_s
    end

    if errors.empty?
      status = "<status>OK</status>\n"
    else
      status = "<status>FAILED</status>\n"
    end
    
    error_string = ""
    errors.each { |e| error_string << "<error>#{e}</error>\n" }
    res.body = "<send-response>\n" + status + error_string + "</send-response>\n"
    
    res['Content-Type'] = "text/html"
    
    raise HTTPStatus::OK
  end
  
  alias :do_POST :do_GET    # let's accept POST request too.
end

class ModemWebServer
  def initialize(config, logger)
    @config, @logger = config, logger
    @s = HTTPServer.new(:Port => @config['http-port'].to_s, :Logger => @logger)
  end
  
  def connect(modem_communicator)
    mountpoint = "/" + modem_communicator.name
    @logger.info "mounting servlet at " + mountpoint
    @s.mount mountpoint, ModemServlet, modem_communicator
  end
  
  def start
    @logger.info "Starting Modem Web Server"
    @s.start
  end
  
  def shutdown
    @s.shutdown
  end
end
