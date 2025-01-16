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
    context 'without key option' do
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

    context 'with key option' do
      let(:options) { { key: '404', number: 2 } }

      it 'returns the specified number of random messages for the key' do
        result = generator.generate
        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result.first).to be_a(String)
      end

      it 'accepts key with or without e prefix' do
        with_e = described_class.new(key: 'e404', number: 1).generate
        without_e = described_class.new(key: '404', number: 1).generate
        expect(with_e).to be_an(Array)
        expect(without_e).to be_an(Array)
      end

      it 'returns empty array for invalid key' do
        result = described_class.new(key: 'invalid', number: 1).generate
        expect(result).to eq([])
      end

      it 'limits number to available messages' do
        result = described_class.new(key: '500', number: 10).generate
        expect(result.length).to eq(2) # e500 only has 2 messages
      end
    end
  end
end
