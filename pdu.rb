require 'date'
require 'utils.rb'
require 'IA5.rb'

# Container class for GSM PDU
# Used to store both outgoing and incoming PDU's
class PDU
	attr_accessor :raw,
	  :smscnumber,
    :typeofaddress,
	  :udh_present,
	  :replypath,
    :originator,
    :coding,
    :flash,
    :messageclass,
    :timestamp,
    :message,
    :udh,
    :destination,
    :parts,
    :partnumber

  alias :flash? :flash
  alias :udh_present? :udh_present

	def initialize(raw = nil)
	  # Set some default values
	  @udh_present = false
	  @flash = false
	  @coding = 7
	  @messageclass = 0
	  @typeofaddress = "91"
	  @parts = 1
	  @partnumber = 1

	  decode(raw) unless raw == nil
	end

	# Decode a received GSM PDU
	def decode(raw)
		@raw = raw
	  (PDUParser.new(self)).parse
	end

  # Encode a GSM PDU for sending via an modem
	def encode
    (PDUEncoder.new(self)).encode
  end

  def length
    (self.encode.length/2)
  end
end

#  PDUEncoder
#  Converts a PDU object to a raw GSM pdu string
class PDUEncoder
  def initialize(pdu)
    @pdu = pdu
  end

  def encode
    length_of_smscinfo +
    sms_submit_octet1 +
    message_reference +
    address_length +
    type_of_address +
    phone_number +
    protocol_identifier +
    data_coding_scheme +
    validity_period +
    user_data_length +
    message
  end

  def length_of_smscinfo
    "00"
  end

  def sms_submit_octet1
    octet = 0x11 # We always use the same validity period format (the relative one)
    octet = octet | 0x40 if @pdu.udh_present?
    return octet.to_s(16)
  end

  def message_reference
    "00" # 00 = Let the phone set the reference number
  end

  def address_length
    @pdu.destination.length.to_hex
  end

  def type_of_address
    "91" # International
  end

  def phone_number
    if (@pdu.destination.length%2 == 1) then
      num = @pdu.destination + "F"
    else
      num = @pdu.destination
    end

    reversed = ""
    0.upto((num.length/2)-1) do |i|
      reversed << num.slice((i*2)+1).chr
      reversed << num.slice(i*2).chr
    end
    reversed
  end

  # See, http://www.dreamfabric.com/sms/pid.html
  def protocol_identifier
    "00"
  end

  def data_coding_scheme
    if (@pdu.coding == 7) then
      "00"
    else
      "04"
    end
  end

  def validity_period
    "AA" # 4 days
  end

  def user_data_length
    @pdu.message.length.to_hex
  end

  def message
    # "E8329BFD4697D9EC37"
    # return @message unless @message == nil
    encode_7bit(@pdu.message)
  end

  def encode_7bit(septets)
    s = septets
    bytes = ""
    s << 0
    0.upto(s.length-2) do |i|
      (next if (i%7 == 0)) unless i == 0
      bytes << ((s[i] >> (i%8)) | (0xFF & s[i+1] << (7-(i%7)))).to_hex
    end
    bytes
  end
end

# Class for parsing a raw PDU string
class PDUParser
	def initialize(pdu)
		@pdu = pdu
		@pos = 0
		@raw = pdu.raw
	end

	def parse
		@pdu.smscnumber = parse_smsc_number
		@pdu.udh_present, @pdu.replypath = *parse_pdu_info # first octet of the SMS-DELIVER message
		@pdu.originator = parse_originator
		parse_protocol_identifier
		@pdu.coding, @pdu.flash, @pdu.messageclass = *parse_data_coding_scheme
		@pdu.timestamp = parse_timestamp
		puts "pdu.timestamp: " + @pdu.timestamp.to_s
		@pdu.message = parse_message
	end

	# 2 bytes
	# 1: length of smsc info
	# 2: type of addr (91 == international)
	def parse_smsc_number
		len = parse_byte # Length of the SMSC information in octets
    type_of_address = next_byte_str # Type-of-address of the SMSC. (91 means international format of the phone number)
    reversed = parse_reversed_number(@raw.slice(@pos+2..@pos+(len*2)-1))
    @pos = @pos + len*2
    return reversed
	end

	def parse_pdu_info
	  pduinfo = parse_byte
	  [ ((pduinfo&0x40)==0x40) , ((pduinfo&0x80)==0x80) ]
	end

	def parse_originator
    addrlen, type_of_addr = next_byte, next_byte

    #puts "parse_originator: addrlen=" + addrlen.to_s + " type of addr:" + type_of_addr.to_s
    #puts "pos before " + @pos.to_s

    addrlen = addrlen + 1 if addrlen%2==1

    sender_number_reversed =  @raw.slice(@pos+2..@pos+addrlen+1)
    #puts "sender_number_reversed: " + sender_number_reversed
    @pos = @pos + addrlen
    parse_reversed_number(sender_number_reversed)
	end

	def parse_protocol_identifier
	  protocol_identifier = next_byte
	  #puts "protocol_identifier: " +  protocol_identifier.to_s
  end

	def parse_data_coding_scheme
	  dcs = next_byte

	  # puts "dcs: " + dcs.to_s

	  if ((dcs&0x0C)==4) then
	    coding = 8
    elsif ((dcs&0x0C)==8)
      coding = 16
    else
      coding = 7
    end

	  [ coding, ((dcs&0x03)==0), dcs&0x03 ]
  end

	def parse_timestamp
    field_names = [ :year, :month, :day, :hour, :minute, :second, :timezone ]
    fields = Hash.new
    field_names.each do |symbol|
      fields[symbol]  = swap_nibble(next_byte_str).to_i
    end

    # will work untill 2070
    if fields[:year].to_i > 70
      fields[:year] = 1900 + fields[:year]
    else
      fields[:year] = 20 + fields[:year]
    end

    # convert timezone to fractions of a day
    timezone = (24*60)/(fields[:timezone].to_i*15)
    timezone = -timezone if ((fields[:timezone].to_i & 0x80) == 0x80)

    DateTime.new(fields[:year], fields[:month], fields[:day], fields[:hour], fields[:minute],fields[:second], timezone)
	end



	def parse_message
	  message_length = next_byte

    message_starts_at = 0

    if @pdu.udh_present == true then
      #@pdu.udh_present.freeze
      pos = @pos
	    udh_len = next_byte # expecting it to be 05
      message_starts_at = (udh_len*(8.0/7.0)).round + 1
      parse_udh(udh_len)
      @pos = pos
    end

    if @pdu.coding == 16 then
      parse_message_16bit(message_length)
    elsif @pdu.coding == 8 then
      parse_message_8bit(message_length)
    else
      parse_message_7bit(message_length).slice(message_starts_at..-1)
    end
  end

	def parse_udh(udh_len)
	  @pdu.udh = @raw.slice(@pos..((udh_len*2)+@pos+1))
    iei = next_byte # expecting it to be 00
    iedl = next_byte # expecting it to be 03
    next_byte
    @pdu.parts = next_byte
    @pdu.partnumber = next_byte
  end

  def parse_message_7bit(len)
      ia5 = []
      rest = 0

      0.upto(len-1) do |ia5pos|
        shift = ia5pos%8
        if shift == 7 then
          ia5 << rest
          rest = 0
        else
          byte = next_byte

          if shift == 0 then
            ia5 << (byte & (0xFF >> 1))
          else
            ia5 << (((byte & (0x7F >> shift)) << shift) | rest)
          end
          rest = byte >> (7-shift)
        end
    end
    message = ""
    ia5.each { |code| message << code.chr }
    return message
  end

  def parse_message_8bit(message_length)
    raise "Not implemented"
  end

  def parse_message_16bit
    raise "Not implemented"
  end

	def parse_byte
		@raw.slice(@pos..(@pos+1)).hex
	end

	def skip_bytes(count)
	  count.times { next_byte }
  end

  def next_byte_str
	  @pos = @pos + 2
    @raw.slice(@pos..(@pos+1))
  end

 	def next_byte
    (next_byte_str()).hex
  end

  def parse_reversed_number(str)
    number = ""
    0.upto((str.length/2)-1) do |i|
      pos = 2*i
      hi, lo = str.slice(pos+1).chr, str.slice(pos).chr
      number << hi
      number << lo unless lo == 'F'
    end
    number
  end

  def swap_nibble(n)
    n.slice!(1).chr + n.slice(0).chr
  end
end
