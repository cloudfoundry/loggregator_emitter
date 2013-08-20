require "loggregator_messages"
require 'socket'

module LoggregatorEmitter

  def self.emit(loggregator_server, target, message)
    s = UDPSocket.new
    s.do_not_reverse_lookup = true
    lm = LogMessage.new()
    lm.timestamp = Time.now.to_i
    lm.message = message
    lm.app_id = target.app_id
    lm.source_type = LogMessage::SourceType::DEA
    lm.message_type = LogMessage::MessageType::OUT

    result = lm.encode.buf
    result.unpack("C*")
    host, port = loggregator_server.split(":")

    s.sendmsg_nonblock(result, 0, Socket.sockaddr_in(port,host))
  rescue Errno::ENOENT => e
    # Just ignore it.
  end
end
