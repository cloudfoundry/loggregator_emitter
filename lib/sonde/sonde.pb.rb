## Generated from sonde.proto for events
require "beefcake"

module Sonde

  class Envelope
    include Beefcake::Message

    module EventType
      LogMessage = 5
    end
  end

  class LogMessage
    include Beefcake::Message

    module MessageType
      OUT = 1
      ERR = 2
    end
  end

  class Envelope
    required :origin, :string, 1
    required :eventType, Envelope::EventType, 2
    optional :timestamp, :int64, 6
    optional :deployment, :string, 13
    optional :job, :string, 14
    optional :index, :string, 15
    optional :ip, :string, 16
    optional :logMessage, LogMessage, 8
  end

  class LogMessage
    required :message, :bytes, 1
    required :message_type, LogMessage::MessageType, 2
    required :timestamp, :int64, 3
    optional :app_id, :string, 4
    optional :source_type, :string, 5
    optional :source_instance, :string, 6
  end
end
