require 'socket'
require 'loggregator_messages/log_message.pb'

class FakeLoggregatorAgent

  attr_reader :messages, :path, :sock

  def initialize(path)
    @messages = []
    @path = path
    @sock = Socket.new(Socket::AF_UNIX, Socket::SOCK_DGRAM, 0)
  end

  def start
    @sock.bind(Socket.pack_sockaddr_un(path))

    @thread = Thread.new do
      while true
        begin
          stuff = @sock.recv(1024)
          messages << LogMessage.decode(stuff)
        rescue Beefcake::Message::WrongTypeError, Beefcake::Message::RequiredFieldNotSetError,  Beefcake::Message::InvalidValueError => e
          puts "ERROR"
          puts e
        end

      end
    end
  end

  def stop(number_expected_messages)
    max_tries = 0
    while messages.length < number_expected_messages
      sleep 0.2
      max_tries += 1
      break if max_tries > 10
    end
    @sock.close
    FileUtils.rm(path)

    Thread.kill(@thread)
  end
end
