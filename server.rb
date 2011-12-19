# Main server
# Christian Theil Have, Feb. 2008

CONFIGURATION_FILE="config.xml"

require 'rubygems'
require 'xmlsimple'
require 'log.rb'
require 'modem_web_server.rb'
require 'modemcom.rb'

class ModemServer
  def initialize(config_file)
    @config = XmlSimple.xml_in config_file
    @config.freeze
    @modems = @config['modem']
    @threads = []
    @modem_communicators = []

    if not @config['logfile'].nil?
      @logger = ModemServerLogger.new(@config['logfile'].to_s)
    else
      puts "No log file specified! Using STDERR."
      @logger = ModemServerLogger.new(STDERR)
    end

    if @config['http-port'].nil?
      @logger.warn "No http-port specified in configuration file. No starting http interface."
    end

    @logger.debug @config.inspect
  end

  def run
    @modem_web_server = ModemWebServer.new(@config, @logger)

    @modems.each do |modemconfig|
      mc = ModemCommunicator.new(modemconfig, @logger)
      @modem_communicators << mc
      @threads << Thread.new { mc.run }
      @modem_web_server.connect mc
    end

    # start web server
    if not @config['http-port'].nil?
      @threads << @modem_web_server_thread = Thread.new { @modem_web_server.run }
    end

    @logger.info "#{@threads.length+1} threads running..."

    trap("INT") do
      @modem_communicators.each { |mc| mc.shutdown }
      @modem_web_server.shutdown
      @threads.join
    end

    @modem_web_server.start
  end
end
