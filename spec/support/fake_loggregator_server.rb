require 'socket'
require 'loggregator_messages/log_message.pb'

class FakeLoggregatorServer

  attr_reader :messages, :port

  def initialize(port)

    puts "#################################################"
    puts `netstat -an`
    puts "#################################################"

    @messages = []
    @port = port

    #this server starts listening on ipv4 and ipv6, so we make two sockets
    @sockets = [UDPSocket.new, UDPSocket.new(Socket::AF_INET6)]
    @threads = []
  end

  def start
    bind_and_record(0, @sockets[0], "0.0.0.0")
    bind_and_record(0, @sockets[1], "::")
  end

  def wait_for_messages(number_expected_messages)
    max_tries = 0
    while messages.length < number_expected_messages
      sleep 0.2
      max_tries += 1
      break if max_tries > 10
    end
  end

  def stop
    @sockets.each { |socket| socket.close }
    @threads.each { |thread| Thread.kill(thread) }
  end

  def reset
    @messages = []
  end

  private

  def bind_and_record(index, socket, server)
    socket.bind(server, @port)

    @threads[index] = Thread.new do
      while true
        begin
          stuff = socket.recv(65536)
          decoded_data = LogMessage.decode(stuff.dup)
          messages << decoded_data
        rescue Beefcake::Message::WrongTypeError, Beefcake::Message::RequiredFieldNotSetError, Beefcake::Message::InvalidValueError => e
          begin
            decoded_data = LogEnvelope.decode(stuff.dup)
            messages << decoded_data
          rescue Beefcake::Message::WrongTypeError, Beefcake::Message::RequiredFieldNotSetError, Beefcake::Message::InvalidValueError => e
            puts "ERROR: neither envelope nor message extraction worked"
            puts e
          end
        end
      end
    end
  end
end
