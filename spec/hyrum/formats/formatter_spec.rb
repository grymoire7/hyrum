# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'a formatter' do |format|
  let(:options) { { format: format } }
  let(:messages) do
    {
      'key1' => ['message 1', 'message 2', 'message 3'],
      'key2' => ['message 4', 'message 5', 'message 6']
    }
  end
  let(:message_strings) { messages.flatten.flatten }

  subject { described_class.new(options) }

  it "#{format} output contains all the message strings" do
    output = subject.format(messages)
    message_strings.each do |message|
      expect(output).to include(message)
    end
  end
end

RSpec.describe Hyrum::Formats::Formatter do
  # Test the formatter for each available format
  Hyrum::Formats::FORMATS.each do |format|
    it_should_behave_like 'a formatter', format.to_s
  end

  describe '#initialize' do
    let(:options) { { format: :json } }

    subject { described_class.new(options) }

    it 'sets the options' do
      expect(subject.options).to eq(options)
    end
  end
end
