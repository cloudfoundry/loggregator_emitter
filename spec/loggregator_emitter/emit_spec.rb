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


  describe "emit_log_envelope" do
    def make_emitter(host)
      LoggregatorEmitter::Emitter.new("#{host}:#{free_port}", LogMessage::SourceType::CLOUD_CONTROLLER, 42, "secret")
    end

    before do
      @server = FakeLoggregatorServer.new(free_port)
      @server.start
    end

    after do
      @server.stop
    end

    it "successfully writes envelope protobuffers" do
      emitter = make_emitter("0.0.0.0")
      emitter.emit("my_app_id", "Hello there!")

      @server.wait_for_messages(1)

      messages = @server.messages

      expect(messages.length).to eq 1
      message = messages[0]
      expect(message.routing_key).to eq "my_app_id"

      actual_digest = Encryption::Symmetric.new.decrypt("secret", message.signature)
      expected_digest = Encryption::Symmetric.new.digest(message.log_message.message)
      expect(actual_digest).to eq expected_digest

      expect(message.log_message.message).to eq "Hello there!"
      expect(message.log_message.app_id).to eq "my_app_id"
      expect(message.log_message.source_type).to eq LogMessage::SourceType::CLOUD_CONTROLLER
      expect(message.log_message.source_id).to eq "42"
      expect(message.log_message.message_type).to eq LogMessage::MessageType::OUT
    end

    it "makes the right protobuffer" do
      emitter = make_emitter("0.0.0.0")

      message = nil
      emitter.stub(:send_protobuffer) do |arg|
        result = arg.encode.buf
        message = result.unpack("C*")
      end
      emitter.emit("my_app_id", "Hello there!")

      # One of the results we saw. For verification that this can be unmarshalled on the go side.
      # [10, 9, 109, 121, 95, 97, 112, 112, 95, 105, 100, 18, 96, 48, 196, 46, 196, 181, 16, 86, 159, 255, 153, 7, 253, 109, 157, 180, 15, 142, 24, 58, 212, 132, 1, 232, 115, 226, 101, 134, 230, 167, 230, 47, 222, 99, 228, 71, 201, 78, 216, 197, 193, 173, 96, 50, 147, 83, 218, 51, 236, 148, 211, 251, 4, 166, 74, 200, 119, 237, 222, 44, 25, 93, 103, 89, 82, 115, 180, 24, 23, 193, 190, 107, 187, 197, 204, 178, 153, 155, 119, 45, 117, 128, 40, 57, 197, 255, 240, 107, 210, 212, 128, 102, 73, 170, 27, 105, 56, 26, 43, 10, 12, 72, 101, 108, 108, 111, 32, 116, 104, 101, 114, 101, 33, 16, 1, 24, 192, 154, 231, 222, 152, 185, 176, 177, 38, 34, 9, 109, 121, 95, 97, 112, 112, 95, 105, 100, 40, 1, 50, 2, 52, 50]
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

      after do
        @server.stop
      end

      it "successfully writes protobuffers using ipv4" do
        emitter = make_emitter("0.0.0.0")
        emitter.send(emit_method, "my_app_id", "Hello there!")
        emitter.send(emit_method, "my_app_id", "Hello again!")
        emitter.send(emit_method, nil, "Hello again!")

        @server.wait_for_messages(2)

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

      it "successfully writes protobuffers using ipv6" do
        emitter = make_emitter("::1")
        emitter.send(emit_method, "my_app_id", "Hello there!")

        @server.wait_for_messages(1)

        messages = @server.messages
        expect(messages.length).to eq 1
        expect(messages[0].message).to eq "Hello there!"
      end

      it "successfully writes protobuffers using a dns name" do
        emitter = make_emitter("localhost")
        emitter.send(emit_method, "my_app_id", "Hello there!")

        @server.wait_for_messages(1)

        messages = @server.messages
        expect(messages.length).to eq 1
        expect(messages[0].message).to eq "Hello there!"
      end

      it "swallows empty messages" do
        emitter = make_emitter("localhost")
        emitter.send(emit_method, "my_app_id", nil)
        emitter.send(emit_method, "my_app_id", "")
        emitter.send(emit_method, "my_app_id", "   ")

        sleep 0.5

        messages = @server.messages
        expect(messages.length).to eq 0
      end
    end
  end

  describe "source id" do
    before do
      @server = FakeLoggregatorServer.new(free_port)
      @server.start
    end

    after do
      @server.stop
    end

    let(:emit_message) do
      @emitter.emit_error("my_app_id", "Hello there!")

      @server.wait_for_messages(2)

      @server.messages[0]
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
