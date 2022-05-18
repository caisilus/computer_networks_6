#!/usr/bin/ruby
# encoding: utf-8

require "celluloid/autostart"
require "celluloid/io" #event based TCPServer instead of TCPServer in 'soket'
require_relative "database.rb"

class Server
  include Celluloid::IO
  finalizer :shutdown

  def initialize(serverPort)
    @serverSocket = TCPServer.new("0.0.0.0", serverPort)
    @serverSocket.listen(10000)
    @concurrentClientCount = 0
    @database = MyDb::LoggingHash.new # для запоминания адресов пользователей
    async.acceptLoop
  end

  def acceptLoop
    loop { async.processClient @serverSocket.accept }
  end

  def processClient(clientSocket)
    begin
      @concurrentClientCount += 1
      puts "#{@concurrentClientCount} concurrent clients are connected"
      # неполный запрос от клиентов (продолжение которого еще не доставилось по сети)
      dataForProcessing = ""
      loop do
        data = clientSocket.recv(100000)
        puts "Data received: "+data
        data.force_encoding('utf-8')
        queries = dataForProcessing + data
        queries = queries.split("\r\n",-1)
        dataForProcessing = queries[-1]
        queries.delete_at(-1)
        queries.each do |query|
          words = query.split(" ")
          command, *arguments = *words
          answer = process_command(command, arguments)
          puts "Answer: "+answer
          clientSocket << answer
        end
      end
    rescue EOFError
      clientSocket.close rescue nil
      @concurrentClientCount -= 1
    rescue Exception => e
      puts "There was exception: " + e.to_s + "\n"+e.backtrace.join("\n")
      shutdown
    end
  end

  def process_command(command, arguments)
    # answer = (eval words[2]+words[1]+words[3]).to_s + "\r\n"
    if command == "set"
      return "2 arguments expected for 'set'\n" if arguments.length != 2
      login, address = *arguments
      register_address(login, address)
    elsif command == "change"
      return "2 arguments expected for 'change'\n" if arguments.length != 2
      login, address = *arguments
      change_address(login, address)
    elsif command == "get"
      return "1 argument expected for 'get'\n" if arguments.length != 1
      login = arguments[0]
      get_address(login)
    else
      "command: #{command} unknown\n"
    end
  end

  def valid_address?(address)
    address.match(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/)
  end

  def address_taken?(address)
    @database.has_value? address
  end

  def register_address(login, address)
    return "Address already set to login\n" if @database.has_key?(login)
    
    return "Invalid ip4 address: #{address}\n" unless valid_address?(address)

    return "Address #{address} is aleady taken\n" if address_taken?(address)

    @database[login] = address
    "Address for #{login} set to #{address}\n"
  end

  def change_address(login, address)
    return "Address does not set to login\n" unless @database.has_key?(login)
    
    return "Invalid ip4 address: #{address}\n" unless valid_address?(address)

    return "Address #{address} is aleady taken\n" if address_taken?(address)

    old_address = @database[login]
    @database[login] = address
    "Address for #{login} changed from #{old_address} to #{address}\n"
  end

  def get_address(login)
    return "Address does not set to login\n" unless @database.has_key?(login)

    "Address for #{login} is #{@database[login]}\n"
  end

  def shutdown
    @serverSocket.close rescue nil
  end
end

server = Server.new(28563)
# ждем нажатия клавиши (ввода строки)
gets
server.shutdown
