class TrieNode < Hash
  attr_accessor :match

  def match_symbol(symbol)
    self[symbol]
  end

  def is_leaf?
    size == 0
  end
end

class TrieParser
  attr :root

  def initialize(symbols)
    @root = TrieNode.new
    symbols.each do |symbol|
      curnode = @root
      rest = symbol.dup
      loop do
        first = rest.slice 0
        rest =  rest.slice 1..-1

        curnode[first] = TrieNode.new if curnode[first].nil?

        if rest.empty? then
          curnode[first].match = symbol
          break
        end

        curnode = curnode[first]
      end
    end
  end

  # Searches a string for the shortest symbol sequence using the trie.´
  # Example: Build trie from 1:"a", 2:"b", 3:"ab", search using string "ababba" -> following sequence of symbols: 3,3,2,1
  def parse(str)
    symbols = []
    trie = @root
    last_match = nil
    last_match_pos = 0
    pos = 0

    while pos < str.length
      char = str.slice(pos)
      prev_trie = trie
      trie = trie[char] # transition

      raise "Cannot match sequence #{char} #{prev_trie.inspect}" if trie.nil?

      if trie.is_leaf?
        if not trie.match.nil?
          last_match = trie
          last_match_pos = pos
        end

        raise "Cannot match sequence" if last_match.nil?

        symbols << last_match.match
        pos = last_match_pos
        last_match = nil
        trie = @root
      else
        if not trie.match.nil?
          if pos == str.length-1
            symbols << trie.match
          else
            last_match = trie
            last_match_pos = pos
          end
        end
      end

      pos = pos + 1
    end
    return symbols
  end
end

