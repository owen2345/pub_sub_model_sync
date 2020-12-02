# frozen_string_literal: true

RSpec.describe PubSubModelSync::Config do
  it 'permits to define configurations' do
    project_id = 'project_id'
    described_class.project = project_id
    expect(described_class.project).to eq project_id
  end

  it 'logs to stdout' do
    msg = 'test msg'
    expect { described_class.log(msg) }.to output(include(msg)).to_stdout
  end
end
