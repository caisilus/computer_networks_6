module MyDb  
  class LoggingHash < Hash
    def []=(key, value)
      puts "Set #{key} to #{value}"
      super
    end
  
    def [](key)
      puts "Get value by #{key}"
      super
    end
  end
end