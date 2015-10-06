require 'socket'
require 'resolv'
require 'sonde/sonde.pb'
require 'sonde/sonde_extender'

module LoggregatorEmitter
  class Emitter

    UDP_SEND_ERROR = StandardError.new("Error sending message via UDP")

    attr_reader :host

    MAX_MESSAGE_BYTE_SIZE = (9 * 1024) - 512
    TRUNCATED_STRING = "TRUNCATED"

    def initialize(loggregator_server, origin, source_type, source_instance = nil)
      @host, @port = loggregator_server.split(/:([^:]*$)/)

      raise ArgumentError, "Must provide valid loggregator server: #{loggregator_server}" if !valid_hostname || !valid_port
      @host = ::Resolv.getaddresses(@host).last
      raise ArgumentError, "Must provide valid loggregator server: #{loggregator_server}" unless @host

      raise ArgumentError, "Must provide a valid origin" unless origin
      raise ArgumentError, "Must provide valid source_type: #{source_type}" unless source_type

      raise ArgumentError, "source_type must be a 3-character string" unless source_type.is_a? String
      raise ArgumentError, "Custom Source String must be 3 characters" unless source_type.size == 3
      @origin = origin
      @source_type = source_type

      @source_instance = source_instance && source_instance.to_s
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
      @host && !@host.empty? && !@host.match(/:\/\//)
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

        send_protobuffer(create_log_envelope(app_id, m, type))
      end
    end

    def create_log_message(app_id, message, type)
      lm = ::Sonde::LogMessage.new()
      lm.time = Time.now
      lm.message = message
      lm.app_id = app_id
      lm.source_instance = @source_instance
      lm.source_type = @source_type
      lm.message_type = type
      lm
    end

    def create_log_envelope(app_id, message, type)
      le = ::Sonde::Envelope.new()
      le.origin = @origin
      le.eventType = ::Sonde::Envelope::EventType::LogMessage
      le.logMessage = create_log_message(app_id, message, type)
      le
    end

    def send_protobuffer(lm)
      result = lm.encode.buf
      result.unpack("C*")

      addrinfo_udp = Addrinfo.udp(@host, @port)
      s = addrinfo_udp.ipv4?() ? UDPSocket.new : UDPSocket.new(Socket::AF_INET6)
      s.do_not_reverse_lookup = true

      begin
        s.sendmsg_nonblock(result, 0, addrinfo_udp)
      rescue
        raise UDP_SEND_ERROR
      end
    end
  end
end
