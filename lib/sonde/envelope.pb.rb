## Generated from envelope.proto for events
require "beefcake"

module Sonde

  class Envelope
    include Beefcake::Message

    module EventType
      HttpStart = 2
      HttpStop = 3
      HttpStartStop = 4
      LogMessage = 5
      ValueMetric = 6
      CounterEvent = 7
      Error = 8
      ContainerMetric = 9
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
    optional :httpStart, HttpStart, 4
    optional :httpStop, HttpStop, 5
    optional :httpStartStop, HttpStartStop, 7
    optional :logMessage, LogMessage, 8
    optional :valueMetric, ValueMetric, 9
    optional :counterEvent, CounterEvent, 10
    optional :error, Error, 11
    optional :containerMetric, ContainerMetric, 12
  end
end
