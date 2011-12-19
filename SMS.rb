class SMS
  attr_accessor :message, :udh, :from, :to, :pdu

  def initialize(message = "", from = "", to = "")
	  @message, @from, @to = message, from, to
	  @udh = ""
  end

  def SMS.create_from_pdu(pdu, modemname = "")
    sms = SMS.new
    sms.message = IA5.decode(pdu.message)
    sms.pdu = pdu
    sms.udh = ""

    if pdu.originator.nil?
      sms.from = modemname
    else
      sms.from = pdu.originator
    end

    if pdu.destination.nil?
    	sms.to = modemname
    else
      sms.to = pdu.destination
    end

    return sms
  end

  def to_pdu
    pdu = PDU.new
    pdu.originator = @from
    pdu.destination = @to
    pdu.message = IA5.encode @message

    return pdu
  end

  def xml
    "<sms>" +
    "<to>" + @to.nil? + "</to>" +
    "<from>" + @from + "</from>" +
    "<message>" + @message + "</message>" +
    "</sms>\n"
  end
end
