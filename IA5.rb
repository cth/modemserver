require 'trie.rb'

class IA5
  @@map_syms = [
      [ '@', '£', '$', '¥', 'è', 'é', 'ù', 'ì', 'ò', 'Ç', '\n', 'Ø', 'ø', '\r', 'Å', 'å' ],
      [ 'Δ', '_', 'Φ', 'Γ', 'Λ', 'Ω', 'Π', 'Ψ', 'Σ', 'Θ', 'Ξ', '\e', 'Æ', 'æ', 'ß', 'É' ],
      [ " ", '!', '"', "#", '¤', "'", '%', '&', '(', ')', '*', '+', ',', '-', '.', '/' ],
      [ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', ':', ';', '<', '=', '>', '?' ],
      [ '¡', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O' ],
      [ 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'Ä', 'Ö', 'Ñ', 'Ü', '§' ],
      [ '¿', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o' ],
      [ 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'ä', 'ö', 'ñ', 'ü', 'à' ]
  ].flatten

  @@map = {}
  @@map_syms.each_with_index { |symbol,index| @@map[symbol] = index }
  @@inv_map = @@map.invert

  @@ext_map = { "|" => 0x40, "^" => 0x14, "€" => 0x65, "{" => 0x28, "}" => 0x29, "[" => 0x3C, "~" => 0x3D, "]" => 0x3E, "\\" => 0x2F }
  @@inv_ext_map = @@ext_map.invert
  @@ext_syms = []
  @@ext_map.each_key { |key| @@ext_syms << key }

  @@trie_parser = TrieParser.new [@@map_syms, @@ext_syms].flatten

  def IA5.is_extended? symbol
    (nil != @@ext_map[symbol])
  end

  def IA5.encode(text)
    ia5 = []

    symbols = @@trie_parser.parse(text)

    symbols.each do |sym|
      if IA5.is_extended? sym
        ia5 << 0x1B << @@ext_map[sym]
      else
        ia5 << @@map[sym]
      end
    end

    ia5
  end

  # expects a byte per ia5 character (do 7bit -> 8bit conversion first)
  def IA5.decode(ia5)
    text, i = "", 0

    while i < ia5.length do
      chr = ia5.slice(i)
      if chr == 0x1B then
        i = i + 1
        puts "extended character: " + chr.to_s + ia5.slice(i).to_s
        text << @@inv_ext_map[ia5.slice(i)]
      elsif not @@inv_map[chr].nil?
        text << @@inv_map[chr]
      else
        puts "unknown ia5 character #{chr}. Skipping"
      end
      i = i + 1
    end

    text
  end
end
