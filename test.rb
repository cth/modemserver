$KCODE = 'u'

require 'test/unit'
require 'pdu.rb'
require 'trie.rb'

class PDUParserTest < Test::Unit::TestCase
  def setup
    # taken from: http://www.dreamfabric.com/sms/
    @raw1 = "07917283010010F5040BC87238880900F10000993092516195800AE8329BFD4697D9EC37"
    @pdu1 = PDU.new(@raw1) # implicit invoke parser
    @raw2 = "06915404939099440A915403322524000080207201406440A00500038E0201A8E5391D442FCFE9207A794E07D1CB733A885E9ED341F4F29C0EA297E77410BD3CA783E8E5391D442FCFE9207A794E07D1CB733A885E9ED341F4F29C0EA297E77410BD3CA783E8E5391D442FCFE9207A794E07D1CB733A885E9ED341F4F29C0EA297E77410BD3CA783E8E5391D442FCFE9207A794E07D1CB733A885E9ED341F4F29C0EA297E7"
    @pdu2 = PDU.new(@raw2)
    @raw3 = "06915404939099640A915403322524000080207201407440120500038E0202E8207A794E07D1CB733A"
    @pdu3 = PDU.new(@raw3)
    @raw4 = "06915404939099440A915412065913000080906151347380A005000304020190D5E912641C829C6F3979AEEEB0D96137790E9AD319F239BD0C5A87DB7090FB7D2EBBE76937B90C4A83C2667AD90D5AB35DA0180E940619C3F27A1B040DCBD7A0F69B0C7AB2F36D783A3C7ECF5DA0E5BB0D4A83CE6F32889E26BB4046F69B0E5A87DB70B8FC7D9687DB207A9A0D0AD341E772BB5D06CDDF6DD0FC5DB797DD6939681D7683D6"
    @pdu4 = PDU.new(@raw4)
    puts @pdu4.inspect

puts	PDU.new("06915404939099440A9154120659130000809061513404803F05000304020218E2F21C647ECB41EBBA1B248381D67217089406CDD16F38BCEC0695D9ECB21C940689DFE4B2DC5D76818E6F32681D6EC301").inspect

  end

  def test_inspect
    #puts @pdu2.inspect
    assert(true)
  end

  def test_message
    #puts @pdu1.inspect
    #puts "pdu.msg: [#{@pdu1.message}]"
    assert(@pdu1.message == "hellohello", "message contents")
  end

  def test_smsc_number
    assert(@pdu1.smscnumber.to_s == "27381000015")
  end

  def test_originator
    assert(@pdu1.originator.to_s == "27838890001")
  end

  def test_udh_present
    assert(@pdu1.udh_present == false)
  end

  def test_coding
    assert(@pdu1.coding == 7)
  end

  def test_messageclass
    assert(@pdu1.messageclass == 0)
  end

  def test_timestamp
    assert(@pdu1.timestamp.year == 1999)
    assert(@pdu1.timestamp.month == 3)
    assert(@pdu1.timestamp.day == 29)
    assert(@pdu1.timestamp.hour == 15)
    assert(@pdu1.timestamp.min == 16)
    assert(@pdu1.timestamp.sec == 59)
  end

  def test_udh_parsing
    assert(@pdu1.udh_present? == false)
    assert(@pdu2.udh_present)
    assert(@pdu3.udh_present)

    assert(@pdu2.udh == "0500038E0201")
    assert(@pdu3.udh == "0500038E0202")

    # parts:
    assert(@pdu2.parts == 2)
    assert(@pdu3.parts == 2)
    assert(@pdu2.partnumber == 1)
    assert(@pdu3.partnumber == 2)
  end
end

class PDUEncoderTest < Test::Unit::TestCase
  def setup
    @pdu = PDU.new
    @pdu.message = "hellohello"
    @pdu.destination  = "46708251358"
    @encoder = PDUEncoder.new(@pdu)
  end

  def test_first_octet
    assert("11"==@encoder.sms_submit_octet1)
  end

  def test_address_length
    assert("0B"==@encoder.address_length)
  end

  def test_phone_number
    assert("6407281553F8"==@encoder.phone_number)
  end

  def test_encode_7bit
    septets = [  104, 101, 108, 108, 111, 104, 101, 108, 108, 111]
    assert(@encoder.encode_7bit(septets)=="E8329BFD4697D9EC37")
  end

  def test_message
    assert(@encoder.message == "E8329BFD4697D9EC37")
  end

  def test_raw
    assert(@encoder.encode == "0011000B916407281553F80000AA0AE8329BFD4697D9EC37")
  end
end

class TrieParserTest < Test::Unit::TestCase
  def test_trie_parser_simple
    tp = TrieParser.new(["a", "b", "ab"])
    assert([] == tp.parse(""))
    assert(["ab", "ab"] == tp.parse("abab"))
    assert(["b", "ab"] == tp.parse("bab"))
    assert(["ab", "a"] == tp.parse("aba"))
    assert(["ab", "ab", "b", "a"] == tp.parse("ababba"))
  end

  def test_trie_parser_special
    tp = TrieParser.new(["\n", "\r", "\e", "\\"])
    puts tp.inspect
    assert([ "\r", "\n", "\\", "\n"] == tp.parse("\r\n\\\n"))
  end

  def test_trie_parser_unicode
    tp = TrieParser.new(["€", "Σ", "ت", "ぁ"])
    assert([ "€", "Σ", "ت", "ぁ"] == tp.parse("€Σتぁ"))
  end
end

class IA5Test < Test::Unit::TestCase
  def test_encode_decode_simple
    assert("abcdefg" == IA5.decode(IA5.encode("abcdefg")))
    assert("€" == IA5.decode(IA5.encode("€")))
  end

  def test_encode_and_decode_basic1
    tmp = "!\"#¤%&'()*+,-./0123456789:;<=>?¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcefghijklmopqrstuvwxyzäöñüà"
    assert(tmp == IA5.decode(IA5.encode(tmp)))
  end
end

require 'test/unit/ui/console/testrunner'
Test::Unit::UI::Console::TestRunner.run(PDUParserTest)
Test::Unit::UI::Console::TestRunner.run(PDUEncoderTest)
Test::Unit::UI::Console::TestRunner.run(TrieParserTest)
Test::Unit::UI::Console::TestRunner.run(IA5Test)
