# frozen_string_literal: true

RSpec.describe PubSubModelSync::Runner do
  let(:inst) { described_class.new }
  let(:connector_klass) { PubSubModelSync::Connector }
  before do
    allow_any_instance_of(connector_klass).to receive(:sleep)
    inst.connector = connector_klass.new
  end
  after { inst.run }

  it '.trap_signals' do
    allow(Signal).to receive(:trap)
    expect(Signal).to receive(:trap).with('QUIT', anything)
  end

  it '.preload_framework' do
    expect(inst).to receive(:preload_framework!)
  end

  it '.start_listeners' do
    expect_any_instance_of(connector_klass).to receive(:listen_messages)
  end

  it 'shutdown' do
    error_klass = PubSubModelSync::Runner::ShutDown
    allow(inst).to receive(:trap_signals!).and_raise(error_klass)
    expect(inst.connector).to receive(:stop)
  end
end