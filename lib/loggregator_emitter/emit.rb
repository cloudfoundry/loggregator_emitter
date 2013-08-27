require "loggregator_messages"
require 'socket'
require "steno"

module LoggregatorEmitter
  class Emitter
    def initialize(loggregator_server, source_type)
      host, port = loggregator_server.split(":")
      raise RuntimeError, "Must provid validate loggregator server: #{loggregator_server}" if (host == nil || port == nil)
      @sockaddr_in = Socket.sockaddr_in(port, host)

      raise RuntimeError, "Must provide valid source type" unless valid_source_type?(source_type)
      @source_type = source_type
    end

    def emit(target, message)
      s = UDPSocket.new
      s.do_not_reverse_lookup = true
      lm = LogMessage.new()
      lm.timestamp = Time.now.to_i
      lm.message = message
      lm.app_id = target.app_id
      lm.source_type = @source_type
      lm.message_type = LogMessage::MessageType::OUT

      result = lm.encode.buf
      result.unpack("C*")

      s.sendmsg_nonblock(result, 0, @sockaddr_in)
    end

    private
    def valid_source_type?(source_type)
      LogMessage::SourceType.constants.each do |name|
        if LogMessage::SourceType.const_get(name) == source_type
          return true
        end
      end
      false
    end
  end
end
