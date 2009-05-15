class Fixnum
        def to_hex(padding_length = 2)
                hex = self.to_s(16).upcase
                padding = ""
                padding="0"*(padding_length-hex.length) if hex.length < padding_length
                padding + hex
        end
end

def is_newline?(char)
  true if (char == "\n" or char == "\r")
end

def readline(socket)
  line = ""
  while not is_newline?(c = socket.read(1))
    line << c
  end
  line
end

def readprompt(socket)
	data = ""
	while not data =~ /> /
		data << socket.read(1)	
	end
end

def readline_block(socket)
	line = nil
	while line.nil? or line.empty? do
		sleep 0.1
		line = readline(socket)
	end
	line
end

def die(str) 
	puts str
	exit -1
end

def hex_to_bins
end
