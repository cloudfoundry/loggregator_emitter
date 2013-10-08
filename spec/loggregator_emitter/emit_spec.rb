require "support/fake_loggregator_server"
require "loggregator_emitter"

describe LoggregatorEmitter do
  class FreePort
    def self.next_free_port
      @@next_free_port ||= 12345
      @@next_free_port += 1
    end
  end
  let(:free_port) do
    FreePort.next_free_port
  end

  describe "configuring emitter" do
    describe "valid configurations" do
      it "is valid with IP and proper source type" do
        expect { LoggregatorEmitter::Emitter.new("0.0.0.0:12345", LogMessage::SourceType::DEA) }.not_to raise_error
      end

      it "is valid with resolveable hostname and proper source type" do
        expect { LoggregatorEmitter::Emitter.new("localhost:12345", LogMessage::SourceType::DEA) }.not_to raise_error
      end

      it "is valid if a server name is given" do
        expect { LoggregatorEmitter::Emitter.new("some-unknown-address:12345", LogMessage::SourceType::DEA) }.not_to raise_error
      end
    end

    describe "invalid configurations" do
      describe "error based on loggregator_server" do
        it "raises if host has protocol" do
          expect { LoggregatorEmitter::Emitter.new("http://0.0.0.0:12345", LogMessage::SourceType::DEA) }.to raise_error(ArgumentError)
        end
      end

      describe "error based on source_type" do
        it "raises if source_type is invalid" do
          expect { LoggregatorEmitter::Emitter.new("0.0.0.0:12345", 40) }.to raise_error(ArgumentError)
        end
      end
    end
  end

  {"emit" => LogMessage::MessageType::OUT, "emit_error" => LogMessage::MessageType::ERR}.each do |emit_method, message_type|
    describe "##{emit_method}" do
      def make_emitter(host)
        LoggregatorEmitter::Emitter.new("#{host}:#{free_port}", LogMessage::SourceType::CLOUD_CONTROLLER, 42)
      end

      before do
        @server = FakeLoggregatorServer.new(free_port)
        @server.start
      end

      it "successfully writes protobuffers to a socket" do
        emitter = make_emitter("0.0.0.0")
        emitter.send(emit_method, "my_app_id", "Hello there!")
        emitter.send(emit_method, "my_app_id", "Hello again!")
        emitter.send(emit_method, nil, "Hello again!")

        @server.wait_for_messages_and_stop(2)

        messages = @server.messages

        expect(messages.length).to eq 2
        message = messages[0]
        expect(message.message).to eq "Hello there!"
        expect(message.app_id).to eq "my_app_id"
        expect(message.source_type).to eq LogMessage::SourceType::CLOUD_CONTROLLER
        expect(message.source_id).to eq "42"
        expect(message.message_type).to eq message_type

        message = messages[1]
        expect(message.message).to eq "Hello again!"
      end

      it "successfully writes protobuffers using a dns name for the loggregator server" do
        emitter = make_emitter("localhost")
        emitter.send(emit_method, "my_app_id", "Hello there!")

        @server.wait_for_messages_and_stop(1)

        messages = @server.messages
        expect(messages.length).to eq 1
        expect(messages[0].message).to eq "Hello there!"
      end
    end
  end

  describe "source id" do
    let(:emit_message) do
      server = FakeLoggregatorServer.new(free_port)
      server.start

      @emitter.emit_error("my_app_id", "Hello there!")

      server.wait_for_messages_and_stop(2)

      server.messages[0]
    end

    it "can be nil" do
      @emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{free_port}", LogMessage::SourceType::CLOUD_CONTROLLER)
      expect(emit_message.source_id).to eq nil
    end

    it "can be passed in as a string" do
      @emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{free_port}", LogMessage::SourceType::CLOUD_CONTROLLER, "some_source_id")
      expect(emit_message.source_id).to eq "some_source_id"
    end

    it "can be passed in as an integer" do
      @emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{free_port}", LogMessage::SourceType::CLOUD_CONTROLLER, 13)
      expect(emit_message.source_id).to eq "13"
    end
  end
end
