require "support/fake_loggregator_server"
require "loggregator_emitter"

describe LoggregatorEmitter do

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

      it "accepts a string as source type/name" do
        expect { LoggregatorEmitter::Emitter.new("localhost:12345", "STG") }.not_to raise_error
      end
    end

    describe "invalid configurations" do
      describe "error based on loggregator_server" do
        it "raises if host has protocol" do
          expect { LoggregatorEmitter::Emitter.new("http://0.0.0.0:12345", LogMessage::SourceType::DEA) }.to raise_error(ArgumentError)
        end

        it "raises if host is blank" do
          expect { LoggregatorEmitter::Emitter.new(":12345", LogMessage::SourceType::DEA) }.to raise_error(Resolv::ResolvError)
        end

        it "raises if host is unresolvable" do
          expect { LoggregatorEmitter::Emitter.new("i.cant.resolve.foo:12345", LogMessage::SourceType::DEA) }.to raise_error(Resolv::ResolvError)
        end

        it "raises if source is an unknown integer" do
          expect { LoggregatorEmitter::Emitter.new("localhost:12345", 7) }.to raise_error(ArgumentError)
        end

        it "raises if source is not an integer or string" do
          expect { LoggregatorEmitter::Emitter.new("localhost:12345", nil) }.to raise_error(ArgumentError)
          expect { LoggregatorEmitter::Emitter.new("localhost:12345", 12.0) }.to raise_error(ArgumentError)
        end

        it "raises if source is too large of a string" do
          expect { LoggregatorEmitter::Emitter.new("localhost:12345", "ABCD") }.to raise_error(ArgumentError)
        end

        it "raises if source is too small of a string" do
          expect { LoggregatorEmitter::Emitter.new("localhost:12345", "AB") }.to raise_error(ArgumentError)
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

      #This test is here to create arrays of bytes to be used in the golang emitter to verify that they are compatible.
      #One of the results we saw:
      #[10, 9, 109, 121, 95, 97, 112, 112, 95, 105, 100, 18, 96, 163, 227, 248, 110, 81, 17, 141, 224, 211, 132, 74, 230, 43, 169, 76, 169, 244, 119, 169, 212, 160, 121, 128, 89, 13, 149, 218, 136, 72, 217, 89, 226, 41, 57, 80, 77, 24, 152, 98, 120, 145, 125, 29, 239, 34, 26, 20, 162, 137, 215, 170, 121, 185, 167, 221, 161, 139, 87, 139, 102, 152, 137, 11, 232, 137, 227, 74, 252, 166, 44, 176, 208, 6, 131, 15, 250, 43, 193, 233, 254, 189, 26, 194, 237, 43, 35, 97, 123, 156, 215, 47, 201, 228, 136, 210, 245, 26, 43, 10, 12, 72, 101, 108, 108, 111, 32, 116, 104, 101, 114, 101, 33, 16, 1, 24, 224, 175, 235, 159, 154, 239, 210, 177, 38, 34, 9, 109, 121, 95, 97, 112, 112, 95, 105, 100, 40, 1, 50, 2, 52, 50]
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

      it "truncates large messages" do
        emitter = make_emitter("localhost")
        message = (124*1024).times.collect { "a" }.join("")
        emitter.send(emit_method, "my_app_id", message)

        sleep 0.5

        messages = @server.messages
        expect(messages.length).to eq 1
        expect(messages[0].message.bytesize <= LoggregatorEmitter::Emitter::MAX_MESSAGE_BYTE_SIZE).to be_true
        expect(messages[0].message.slice(-9..-1)).to eq("TRUNCATED")
      end

      it "splits messages by newlines" do
        emitter = make_emitter("localhost")
        message = "hi\n\rworld\nhow are you\r\ndoing\r"
        emitter.send(emit_method, "my_app_id", message)

        sleep 0.5
        messages = @server.messages
        expect(messages.length).to eq 4
      end
    end
  end

  describe "source" do
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

    it "when type is known" do
      @emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{free_port}", LogMessage::SourceType::CLOUD_CONTROLLER)
      expect(emit_message.source_name).to eq "CLOUD_CONTROLLER"
    end

    it "when type is unknown" do
      @emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{free_port}", "STG")
      expect(emit_message.source_name).to eq "STG"
      expect(emit_message.source_type).to eq LogMessage::SourceType::UNKNOWN
    end

    it "id can be nil" do
      @emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{free_port}", LogMessage::SourceType::CLOUD_CONTROLLER)
      expect(emit_message.source_id).to eq nil
    end

    it "id can be passed in as a string" do
      @emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{free_port}", LogMessage::SourceType::CLOUD_CONTROLLER, "some_source_id")
      expect(emit_message.source_id).to eq "some_source_id"
    end

    it "id can be passed in as an integer" do
      @emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{free_port}", LogMessage::SourceType::CLOUD_CONTROLLER, 13)
      expect(emit_message.source_id).to eq "13"
    end
  end
end
