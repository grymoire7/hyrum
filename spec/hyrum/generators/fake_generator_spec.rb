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
        expect(fake_messages['e404']).to include("Not Found: The requested resource could not be located")
        expect(fake_messages['e418']).to include("I'm a teapot: Server refuses to brew coffee with a teapot")
        expect(fake_messages['e500']).to include("Internal Server Error: Something went wrong on our end")
        expect(fake_messages['e503']).to include("Service Unavailable: Server temporarily unavailable")
        expect(fake_messages['e504']).to include("Gateway Timeout: Upstream server timed out")
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

      it 'generates different numbers of messages based on the number option' do
        [1, 3, 5].each do |num|
          generator = described_class.new(key: '404', number: num)
          result = generator.generate
          expect(result.length).to eq(num)
          expect(result.uniq.length).to eq(num) # Ensure messages are unique
        end
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
        messages = JSON.parse(described_class::FAKE_MESSAGES)
        max_messages = messages['e500'].length
        requested_messages = max_messages + 1
        result = described_class.new(key: '500', number: requested_messages).generate
        expect(result.length).to eq(max_messages)
      end
    end
  end
end
