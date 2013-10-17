require 'socket'

module LoggregatorEmitter
  class Emitter
    def initialize(loggregator_server, source_type, source_id = nil)
      raise ArgumentError, "Must provide valid source type" unless valid_source_type?(source_type)

      @host, @port = loggregator_server.split(/:([^:]*$)/)
      raise ArgumentError, "Must provide valid loggregator server: #{loggregator_server}" if !valid_hostname || !valid_port

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

    def valid_port
      @port && @port.match(/^\d+$/)
    end

    def valid_hostname
      @host && !@host.match(/:\/\//)
    end

    def emit_message(app_id, message, type)
      return unless app_id && message && message.strip.length > 0

      lm = create_log_message(app_id, message, type)
      send_message(lm)
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
      result = lm.encode.buf
      result.unpack("C*")

      addrinfo_udp = Addrinfo.udp(@host, @port)
      s = addrinfo_udp.ipv4?() ? UDPSocket.new : UDPSocket.new(Socket::AF_INET6)
      s.do_not_reverse_lookup = true
      s.sendmsg_nonblock(result, 0, addrinfo_udp)
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
