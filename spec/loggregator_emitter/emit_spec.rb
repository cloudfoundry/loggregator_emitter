# encoding: UTF-8
require "spec_helper"
require "support/fake_loggregator_server"
require "loggregator_emitter"

describe LoggregatorEmitter do

  before :all do
    @free_port = 12345
    @server = FakeLoggregatorServer.new(@free_port)
    @server.start
  end

  after :all do
    @server.stop
  end

  before do
    @server.reset
  end

  describe "configuring emitter" do
    describe "valid configurations" do
      it "is valid with IP and proper source name" do
        expect { LoggregatorEmitter::Emitter.new("0.0.0.0:12345", "origin", "DEA") }.not_to raise_error
      end

      it "is valid with resolveable hostname and proper source name" do
        expect { LoggregatorEmitter::Emitter.new("localhost:12345", "origin", "DEA") }.not_to raise_error
      end

      it "accepts a string as source type/name" do
        expect { LoggregatorEmitter::Emitter.new("localhost:12345", "origin", "STG") }.not_to raise_error
      end
    end

    describe "invalid configurations" do
      describe "error based on loggregator_server" do
        it "raises if host has protocol" do
          expect { LoggregatorEmitter::Emitter.new("http://0.0.0.0:12345", "origin", "DEA") }.to raise_error(ArgumentError)
        end

        it "raises if host is blank" do
          expect { LoggregatorEmitter::Emitter.new(":12345", "origin", "DEA") }.to raise_error(ArgumentError)
        end

        it "raises if host is unresolvable" do
          expect { LoggregatorEmitter::Emitter.new("i.cant.resolve.foo:12345", "origin", "DEA") }.to raise_error(ArgumentError)
        end

        it "raises if origin is blank" do
          expect { LoggregatorEmitter::Emitter.new(":12345", "", "DEA") }.to raise_error(ArgumentError)
        end

        it "raises if source_type is an unknown integer" do
          expect { LoggregatorEmitter::Emitter.new("localhost:12345", "origin", 7) }.to raise_error(ArgumentError)
        end

        it "raises if source_type is not an integer or string" do
          expect { LoggregatorEmitter::Emitter.new("localhost:12345", "origin", nil) }.to raise_error(ArgumentError)
          expect { LoggregatorEmitter::Emitter.new("localhost:12345", "origin", 12.0) }.to raise_error(ArgumentError)
        end

        it "raises if source_type is too large of a string" do
          expect { LoggregatorEmitter::Emitter.new("localhost:12345", "origin", "ABCD") }.to raise_error(ArgumentError)
        end

        it "raises if source_type is too small of a string" do
          expect { LoggregatorEmitter::Emitter.new("localhost:12345", "origin", "AB") }.to raise_error(ArgumentError)
        end
      end
    end
  end


  describe "emit_log_envelope" do
    def make_emitter(host)
      LoggregatorEmitter::Emitter.new("#{host}:#{@free_port}", "origin", "API", 42)
    end

    it "successfully writes envelope protobuffers" do
      emitter = make_emitter("0.0.0.0")
      emitter.emit("my_app_id", "Hello there!")

      @server.wait_for_messages(1)

      messages = @server.messages

      expect(messages.length).to eq 1
      message = messages[0]

      expect(message.logMessage.message).to eq "Hello there!"
      expect(message.logMessage.app_id).to eq "my_app_id"
      expect(message.logMessage.source_instance).to eq "42"
      expect(message.logMessage.message_type).to eq ::Sonde::LogMessage::MessageType::OUT
    end

    it "gracefully handles failures to send messages" do
      emitter = make_emitter("0.0.0.0")
      UDPSocket.any_instance.stub(:sendmsg_nonblock).and_raise("Operation not permitted - sendmsg(2) (Errno::EPERM)")

      expect {emitter.emit("my_app_id", "Hello there!")}.to raise_error(LoggregatorEmitter::Emitter::UDP_SEND_ERROR)
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
        LoggregatorEmitter::Emitter.new("#{host}:#{@free_port}", "origin", "API", 42)
      end

      it "successfully writes protobuffers using ipv4" do
        emitter = make_emitter("127.0.0.1")
        emitter.send(emit_method, "my_app_id", "Hello there!")
        emitter.send(emit_method, "my_app_id", "Hello again!")
        emitter.send(emit_method, nil, "Hello again!")

        @server.wait_for_messages(2)

        messages = @server.messages

        expect(messages.length).to eq 2
        message = messages[0].logMessage
        expect(message.message).to eq "Hello there!"
        expect(message.app_id).to eq "my_app_id"
        expect(message.source_instance).to eq "42"
        expect(message.message_type).to eq message_type

        message = messages[1].logMessage
        expect(message.message).to eq "Hello again!"
      end

      it "successfully writes protobuffers using ipv6" do
        emitter = make_emitter("::1")
        emitter.send(emit_method, "my_app_id", "Hello there!")

        @server.wait_for_messages(1)

        messages = @server.messages
        expect(messages.length).to eq 1
        expect(messages[0].logMessage.message).to eq "Hello there!"
      end

      it "successfully writes protobuffers using a dns name" do
        emitter = make_emitter("localhost")
        emitter.send(emit_method, "my_app_id", "Hello there!")

        @server.wait_for_messages(1)

        messages = @server.messages
        expect(messages.length).to eq 1
        expect(messages[0].logMessage.message).to eq "Hello there!"
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
        logMessage = messages[0].logMessage
        expect(logMessage.message.bytesize <= LoggregatorEmitter::Emitter::MAX_MESSAGE_BYTE_SIZE).to be_true
        expect(logMessage.message.slice(-9..-1)).to eq("TRUNCATED")
      end

      it "splits messages by newlines" do
        emitter = make_emitter("localhost")
        message = "hi\n\rworld\nhow are you\r\ndoing\r"
        emitter.send(emit_method, "my_app_id", message)

        sleep 0.5
        messages = @server.messages
        expect(messages.length).to eq 4
      end

      it "sends messages with unicode characters " do
        emitter = make_emitter("localhost")
        message = "測試".encode("utf-8")
        emitter.send(emit_method, "my_app_id", message)

        sleep 0.5

        messages = @server.messages
        expect(messages.length).to eq 1
        expect(messages[0].logMessage.message.force_encoding("utf-8")).to eq "測試"
      end
    end
  end

  describe "source" do

    let(:emit_message) do
      @emitter.emit_error("my_app_id", "Hello there!")

      @server.wait_for_messages(2)

      @server.messages[0].logMessage
    end

    it "when type is known" do
      @emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "API")
      expect(emit_message.source_type).to eq "API"
    end

    it "when type is unknown" do
      @emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "STG")
      expect(emit_message.source_type).to eq "STG"
    end

    it "id can be nil" do
      @emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "API")
      expect(emit_message.source_instance).to eq nil
    end

    it "id can be passed in as a string" do
      @emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "API", "some_source_id")
      expect(emit_message.source_instance).to eq "some_source_id"
    end

    it "id can be passed in as an integer" do
      @emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "API", 13)
      expect(emit_message.source_instance).to eq "13"
    end
  end
end
