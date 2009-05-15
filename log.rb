require 'logger'
require 'monitor'

class ModemServerLogger < Monitor
  def initialize(logfile)
    @filename = logfile
    open 
    @logger.info "Log #{@filename} startet"
    @logger.level = Logger::INFO
  end
  
  def open 
    #@file = File.open(@filename, File::WRONLY | File::APPEND | File::CREAT)
    #@logger = Logger.new(@file, 'daily')
    @logger = Logger.new(@filename, 'daily')
    @logger.level = Logger::INFO
  end
  
  def close
    @logger.close     
  end
  
  def shutdown
    close
  end

  # catch method call, synchronize and send to the logger object
  def method_missing(m, *args)
    @logger.send(m, *args) 
    puts *args
    #@file.flush
  end
end
