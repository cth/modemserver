class PlaceHolder
	def method_missing(method, *args)
		puts "PlaceHolder.#{method}(#{args.inspect})"
	end
end
