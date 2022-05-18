#!/usr/bin/python
# -*- coding: UTF-8 -*-
from twisted.internet import reactor
from autobahn.twisted.websocket import WebSocketServerProtocol, WebSocketServerFactory
import re

port = 28563
concurrentClientCount = 0

class ProcessClient(WebSocketServerProtocol):
    def __init__(self, *args, **kwargs):
        self.db = {}
        super(*args, **kwargs)

    def onConnect(self, request):
        global concurrentClientCount
        concurrentClientCount += 1
        print("Client connecting: {0}".format(request.peer))
        print(concurrentClientCount, "concurrent clients are connected")

    def onClose(self, wasClean, code, reason):
        global concurrentClientCount
        concurrentClientCount -= 1
        print("WebSocket connection closed: {0}".format(reason))

    def onMessage(self, data, isBinary):
        #self - это клиент
        if isBinary:
          print("Can't anwer to binary message")
          return
        data = data.decode('utf8')
        print("Data received: "+data)
        words = data.split(" ")
        command, *arguments = words
        answer = self.process_query(command, arguments)
        self.sendMessage(answer.encode('utf8'), False)
        print("Answer: "+answer)

    def process_query(self, command, arguments):
        answer = ""
        if command == "set":
            if len(arguments) != 2:
                return "2 arguments expected for 'set'\n"
            login, address = arguments
            answer = self.register_address(login, address)
        elif command == "change":
            if len(arguments) != 2:
                return "2 arguments expected for 'change'\n"
            login, address = arguments
            answer = self.change_address(login, address)
        elif command == "get":
            if len(arguments) != 1:
                return "1 argument expected for 'get'\n"
            login = arguments[0]
            answer = self.get_address(login)
        else:
            answer = f"Command {command} is unknown"
        return answer

    def is_address_valid(self, address):
        match = re.match(r"\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}", address)
        return match is not None

    def is_address_taken(self, address):
        return address in self.db.values()

    def register_address(self, login, address):
        if login in self.db.keys():
            return "Address already set to login\n"
        if not self.is_address_valid(address):
            return f"Invalid ip4 address: {address}\n"
        if self.is_address_taken(address):
            return f"Address {address} is aleady taken\n"
        
        self.db[login] = address
        
        return f"Address for {login} set to {address}\n"

    def change_address(self, login, address):
        if login not in self.db.keys():
            return "Address does not set to login\n"
        if not self.is_address_valid(address):
            return f"Invalid ip4 address: {address}\n"
        if self.is_address_taken(address):
            return f"Address {address} is aleady taken\n"
        
        old_address = self.db[login]
        self.db[login] = address
        
        return f"Address for {login} changed from {old_address} to {address}\n"
    
    def get_address(self, login):
        if login not in self.db.keys():
            return "Address does not set to login\n"

        address = self.db[login]
        
        return f"Address for {login} is {address}\n"
   

factory = WebSocketServerFactory(u"ws://0.0.0.0:"+str(port))
factory.protocol = ProcessClient
reactor.listenTCP(port, factory)
reactor.run()
