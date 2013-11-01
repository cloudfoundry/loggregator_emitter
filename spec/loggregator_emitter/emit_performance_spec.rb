require "support/fake_loggregator_server"
require "loggregator_emitter"

class MessageFixture
  attr_reader :name, :message

  def initialize(name, message, server_threshold, no_server_threshold)
    @name = name
    @message = message
    @server_threshold = server_threshold
    @no_server_threshold = no_server_threshold
  end

  def expected(using_server)
    using_server ? @server_threshold : @no_server_threshold
  end
end

class FreePort
  def self.next_free_port
    @@next_free_port ||= 12345
    @@next_free_port += 1
  end
end

shared_examples "a performance test" do |fixture, using_server|
  let(:free_port) { FreePort.next_free_port }
  let(:iterations) { using_server ? 100 : 1000 }
  subject(:emitter) { LoggregatorEmitter::Emitter.new("localhost:#{free_port}", "API", 42, "my-secret") }

  before do
    if using_server
      @server = FakeLoggregatorServer.new(free_port)
      @server.start
    else
      emitter.should_receive(:send_protobuffer).at_least(iterations).times
    end
  end

  after do
    @server.stop if using_server
  end

  it "emits #{fixture.name} within a time threshold #{using_server ? 'with' : 'without'} server" do
    start_time = Time.now.to_f

    iterations.times { emitter.emit("my_app_id", fixture.message) }

    expect(Time.now.to_f - start_time).to be < fixture.expected(using_server)
  end

end

describe LoggregatorEmitter do
  @fixtures = []
  @fixtures << MessageFixture.new("long_message", (124*1024).times.collect { "a" }.join(""), 2.0, 2.0)
  @fixtures << MessageFixture.new("message with newlines", 10.times.collect { (6*1024).times.collect { "a" }.join("") + "\n" }.join(""), 3.0, 3.0)
  @fixtures << MessageFixture.new("message worst case", (124*1024).times.collect { "a" }.join("") + "\n", 2.0, 2.0)

  [true, false].each do |using_server|
    @fixtures.each do |fixture|
      it_behaves_like "a performance test", fixture, using_server
    end
  end
end