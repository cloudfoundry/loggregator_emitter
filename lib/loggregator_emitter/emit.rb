require "loggregator_messages/log_message.pb"

module LoggregatorEmitter

  def self.emit(sock, target, message)
    s = Socket.new(Socket::AF_UNIX, Socket::SOCK_DGRAM, 0)
    lm = LogMessage.new()
    lm.timestamp = Time.now.to_i
    lm.message = message
    lm.app_id = target.app_id
    lm.source_type = LogMessage::SourceType::DEA
    lm.organization_id = target.organization_id
    lm.space_id = target.space_id
    lm.message_type = LogMessage::MessageType::OUT

    result = lm.encode.buf
    result.unpack("C*")

    s.connect(Socket.pack_sockaddr_un(sock))
    s.send(result, 0)
  rescue Errno::ENOENT => e
    # Just ignore it.
  end
end
