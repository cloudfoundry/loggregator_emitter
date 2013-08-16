require 'support/fake_loggregator_agent'
require 'loggregator_emitter/emit'
require 'loggregator_emitter/target'

describe "Writing to Unix Sockets" do
  let(:target) { LoggregatorEmitter::Target.new("orgId", "spaceId", "appId") }

  before do
    FileUtils.rm("/tmp/loggregator_emitter.sock", :force => true)
  end

  it "successfully writes protobuffer to a socket" do
    agent = FakeLoggregatorAgent.new("/tmp/loggregator_emitter.sock")
    agent.start

    LoggregatorEmitter.emit("/tmp/loggregator_emitter.sock", target, "Hello there!")
    LoggregatorEmitter.emit("/tmp/loggregator_emitter.sock", target, "Hello again!")

    agent.stop(2)

    messages = agent.messages

    expect(messages.length).to eq 2
    message = messages[0]
    expect(message.message).to eq "Hello there!"
    expect(message.organization_id).to eq target.organization_id
    expect(message.space_id).to eq target.space_id
    expect(message.app_id).to eq target.app_id

    message = messages[1]
    expect(message.message).to eq "Hello again!"
  end

  it "continues to work if there is no agent listening" do
    expect{LoggregatorEmitter.emit("/tmp/loggregator_emitter.sock", target, "Hello there!")}.not_to raise_error
  end
end
