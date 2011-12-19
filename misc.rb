


def ia5(str)
    len = ((str.length/2) * (8.0/7.0)).round

    pos = 0
    ia5 = []
    rest = 0

    0.upto(len-1) do |ia5pos|
      shift = ia5pos%8
      if shift == 7 then
        ia5 << rest
        rest = 0
      else
        # Extract next byte
        byte = (str.slice(pos..(pos+1))).hex
    	  pos = pos + 2

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

puts(ia5("B4DA0C269BD5643419"))
puts(ia5("2B5A4D168BC96237D80C"))



