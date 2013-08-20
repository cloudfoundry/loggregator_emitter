require 'support/fake_loggregator_server'
require 'loggregator_emitter/emit'
require 'loggregator_emitter/target'

describe "Writing to Sockets" do
  let(:target) { LoggregatorEmitter::Target.new("appId") }

  it "successfully writes protobuffer to a socket" do
    server = FakeLoggregatorServer.new(12345)
    server.start

    LoggregatorEmitter.emit('localhost:12345', target, "Hello there!")
    LoggregatorEmitter.emit('localhost:12345', target, "Hello again!")

    server.stop(2)

    messages = server.messages

    expect(messages.length).to eq 2
    message = messages[0]
    expect(message.message).to eq "Hello there!"
    expect(message.app_id).to eq target.app_id

    message = messages[1]
    expect(message.message).to eq "Hello again!"
  end

  it "continues to work if there is no server listening" do
    expect{LoggregatorEmitter.emit('localhost:12345', target, "Hello there!")}.not_to raise_error
  end
end
