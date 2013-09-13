require "loggregator_messages"
require 'socket'

module LoggregatorEmitter
  class Emitter
    def initialize(loggregator_server, source_type)
      host, port = loggregator_server.split(":")
      raise RuntimeError, "Must provide valid loggregator server: #{loggregator_server}" if (host == nil || port == nil)
      raise RuntimeError, "Must provide IP address for loggregator server: #{loggregator_server}" unless host.match(/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/)
      @sockaddr_in = Socket.sockaddr_in(port, host)

      raise RuntimeError, "Must provide valid source type" unless valid_source_type?(source_type)
      @source_type = source_type
    end

    def emit(app_id, message)
      if app_id
        lm = create_log_message(app_id, message, LogMessage::MessageType::OUT)
        send_message(lm)
      end
    end

    def emit_error(app_id, message)
      if app_id
        lm = create_log_message(app_id, message, LogMessage::MessageType::ERR)
        send_message(lm)
      end
    end

    private
    def create_log_message(app_id, message, type)
      lm = LogMessage.new()
      lm.time = Time.now
      lm.message = message
      lm.app_id = app_id
      lm.source_type = @source_type
      lm.message_type = type
      lm
    end

    def send_message(lm)
      s = UDPSocket.new
      s.do_not_reverse_lookup = true

      result = lm.encode.buf
      result.unpack("C*")

      s.sendmsg_nonblock(result, 0, @sockaddr_in)
    end

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
