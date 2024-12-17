require 'spec_helper'

RSpec.describe Hyrum::Generators::FakeGenerator do
  let(:options) { { ai_service: 'test_service' } }
  let(:generator) { described_class.new(options) }

  describe '#initialize' do
    it 'sets the options' do
      expect(generator.options).to eq(options)
    end
  end

  describe '#generate' do
    it 'returns parsed JSON of FAKE_MESSAGES' do
      fake_messages = JSON.parse(Hyrum::Generators::FakeGenerator::FAKE_MESSAGES)
      expect(generator.generate).to eq(fake_messages)
    end

    it 'includes expected error messages' do
      fake_messages = generator.generate
      expect(fake_messages['e404']).to include("We couldn't locate the resource you were looking for.")
      expect(fake_messages['e418']).to include("I'm a teapot")
      expect(fake_messages['e500']).to include("Internal Server Error")
      expect(fake_messages['e503']).to include("Service Unavailable")
      expect(fake_messages['e504']).to include("Gateway Timeout")
    end
  end
end