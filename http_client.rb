#require 'CGI'
# $Id: http_client.rb,v 1.7 2008/04/22 13:02:45 cth Exp $
require 'net/http'

class HTTPClient
  def initialize(baseurl, logger)
    @baseurl, @logger = baseurl, logger
  end

  def send_http_request(sms)
    @logger.info "Forwarding message to #{@baseurl}"
    response = Net::HTTP.post_form(URI.parse(@baseurl), { "message" => sms.message, "pdu" => sms.pdu, "from" => sms.from, "to" => sms.to, "parts" => sms.pdu.parts.to_s, "partnumber" => sms.pdu.partnumber.to_s  })
    @logger.info "Response: " + response.body
  end

  def construct_url(sms)
    url = @baseurl
    url << "?message=" + CGI.escape(sms.message)
    url << "&pdu=" + CGI.escape(sms.pdu)
    url << "&from=" + CGI.escape(sms.from)
    url << "&to=" + CGI.escape(sms.to)
  end
end
