require 'socket'

module LoggregatorEmitter
  class Emitter
    def initialize(loggregator_server, source_type, source_id = nil)
      raise ArgumentError, "Must provide valid source type" unless valid_source_type?(source_type)

      @host, @port = loggregator_server.split(":")
      raise ArgumentError, "Must provide valid loggregator server: #{loggregator_server}" if (@host == nil || @port == nil || !@port.match(/^\d+$/))

      @source_type = source_type
      @source_id = source_id && source_id.to_s
    end

    def emit(app_id, message)
      emit_message(app_id, message, LogMessage::MessageType::OUT)
    end

    def emit_error(app_id, message)
      emit_message(app_id, message, LogMessage::MessageType::ERR)
    end

    private

    def emit_message(app_id, message, type)
      if app_id
        lm = create_log_message(app_id, message, type)
        send_message(lm)
      end
    end

    def create_log_message(app_id, message, type)
      lm = LogMessage.new()
      lm.time = Time.now
      lm.message = message
      lm.app_id = app_id
      lm.source_id = @source_id
      lm.source_type = @source_type
      lm.message_type = type
      lm
    end

    def send_message(lm)
      s = UDPSocket.new
      s.do_not_reverse_lookup = true

      result = lm.encode.buf
      result.unpack("C*")

      s.sendmsg_nonblock(result, 0, Socket.sockaddr_in(@port, @host))
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
