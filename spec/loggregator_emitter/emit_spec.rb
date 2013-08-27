require 'support/fake_loggregator_server'
require 'loggregator_emitter/emit'
require 'loggregator_emitter/target'

describe LoggregatorEmitter do

  let(:target) { LoggregatorEmitter::Target.new('appId') }

  describe 'configuring emitter' do

    it 'can be configured' do
      expect { LoggregatorEmitter::Emitter.new('0.0.0.0:12345', LogMessage::SourceType::DEA) }.not_to raise_error
    end

    it 'raises if loggregator_server is invalid' do
      expect { LoggregatorEmitter::Emitter.new('0.0.0.0', LogMessage::SourceType::DEA) }.to raise_error(RuntimeError)
    end

    it 'doesnt raise if source_type is valid' do
      expect { LoggregatorEmitter::Emitter.new('0.0.0.0:12345', LogMessage::SourceType::DEA) }.not_to raise_error
    end

    it 'raises if source_type is invalid' do
      expect { LoggregatorEmitter::Emitter.new('0.0.0.0:12345', 40) }.to raise_error(RuntimeError)
    end
  end

  describe 'Writing to Sockets' do
    before(:each) do
      @emitter = LoggregatorEmitter::Emitter.new('0.0.0.0:12345', LogMessage::SourceType::CLOUD_CONTROLLER)
    end

    it 'successfully writes protobuffer to a socket' do
      server = FakeLoggregatorServer.new(12345)
      server.start

      @emitter.emit(target, 'Hello there!')
      @emitter.emit(target, 'Hello again!')

      server.stop(2)

      messages = server.messages

      expect(messages.length).to eq 2
      message = messages[0]
      expect(message.message).to eq 'Hello there!'
      expect(message.app_id).to eq target.app_id
      expect(message.source_type).to eq LogMessage::SourceType::CLOUD_CONTROLLER

      message = messages[1]
      expect(message.message).to eq 'Hello again!'
    end
  end
end
