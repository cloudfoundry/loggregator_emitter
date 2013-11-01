require 'socket'

module LoggregatorEmitter
  class Emitter
    MAX_MESSAGE_BYTE_SIZE = (9 * 1024) - 512
    TRUNCATED_STRING = "TRUNCATED"

    def initialize(loggregator_server, source_type, source_id = nil, secret=nil)
      @host, @port = loggregator_server.split(/:([^:]*$)/)
      raise ArgumentError, "Must provide valid loggregator server: #{loggregator_server}" if !valid_hostname || !valid_port

      @secret = secret
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

    def split_message(message)
      message.split(/\n|\r/).reject { |a| a.empty? }
    end

    def emit_message(app_id, message, type)
      return unless app_id && message && message.strip.length > 0

      split_message(message).each do |m|
        if m.bytesize > MAX_MESSAGE_BYTE_SIZE
          m = m.byteslice(0, MAX_MESSAGE_BYTE_SIZE-TRUNCATED_STRING.bytesize) + TRUNCATED_STRING
        end

        if @secret.nil? || @secret.empty?
          send_protobuffer(create_log_message(app_id, m, type))
        else
          send_protobuffer(create_log_envelope(app_id, m, type))
	      end
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

    def create_log_envelope(app_id, message, type)
      crypter = Encryption::Symmetric.new
      le = LogEnvelope.new()
      le.routing_key = app_id
      le.log_message = create_log_message(app_id, message, type)
      digest = crypter.digest(le.log_message.message)
      le.signature = crypter.encrypt(@secret, digest)
      le
    end

    def send_protobuffer(lm)
      result = lm.encode.buf
      result.unpack("C*")

      addrinfo_udp = Addrinfo.udp(@host, @port)
      s = addrinfo_udp.ipv4?() ? UDPSocket.new : UDPSocket.new(Socket::AF_INET6)
      s.do_not_reverse_lookup = true
      s.sendmsg_nonblock(result, 0, addrinfo_udp)
    end
  end
end
