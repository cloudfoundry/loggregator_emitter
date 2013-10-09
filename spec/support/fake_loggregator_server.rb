require 'socket'
require 'loggregator_messages/log_message.pb'

class FakeLoggregatorServer

  attr_reader :messages, :port

  def initialize(port)
    @messages = []
    @port = port

    #this server starts listening on ipv4 and ipv6, so we make two sockets
    @sockets = [UDPSocket.new, UDPSocket.new(Socket::AF_INET6)]
    @threads = []
  end

  def start
    bind_and_record(0, @sockets[0], "localhost")
    bind_and_record(0, @sockets[1], "::1")
  end

  def wait_for_messages_and_stop(number_expected_messages)
    max_tries = 0
    while messages.length < number_expected_messages
      sleep 0.2
      max_tries += 1
      break if max_tries > 10
    end

    @sockets.each { |socket| socket.close}
    @threads.each { |thread| Thread.kill(thread) }
  end

  private

  def bind_and_record(index, socket, server)
    socket.bind(server, port)

    @threads[index] = Thread.new do
      while true
        begin
          stuff = socket.recv(65536)
          messages << LogMessage.decode(stuff)
        rescue Beefcake::Message::WrongTypeError, Beefcake::Message::RequiredFieldNotSetError, Beefcake::Message::InvalidValueError => e
          puts "ERROR"
          puts e
        end
      end
    end
  end
end
