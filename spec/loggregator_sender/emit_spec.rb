require 'support/fake_loggregator_agent'
require 'loggregator_sender/sender'
require 'loggregator_sender/target'

describe "Writing to Unix Sockets" do
  let(:target) { Target.new("orgId", "spaceId", "appId") }

  before do
    FileUtils.rm("/tmp/loggregator_sender.sock", :force => true)
  end

  it "successfully writes protobuffer to a socket" do
    agent = FakeLoggregatorAgent.new("/tmp/loggregator_sender.sock")
    agent.start

    LoggregatorSender.emit("/tmp/loggregator_sender.sock", target, "Hello there!")
    LoggregatorSender.emit("/tmp/loggregator_sender.sock", target, "Hello again!")

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
    expect{LoggregatorSender.emit("/tmp/loggregator_sender.sock", target, "Hello there!")}.not_to raise_error
  end
end
