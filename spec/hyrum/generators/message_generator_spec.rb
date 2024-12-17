require 'spec_helper'

RSpec.describe Hyrum::Generators::MessageGenerator do
  let(:valid_options_openai) { { ai_service: :openai } }
  let(:valid_options_ollama) { { ai_service: :ollama } }
  let(:valid_options_fake) { { ai_service: :fake } }
  let(:invalid_options) { { ai_service: :invalid } }

  describe '.create' do
    context 'with valid openai service' do
      it 'returns an instance of OpenaiGenerator' do
        generator = described_class.create(valid_options_openai)
        expect(generator).to be_instance_of(Hyrum::Generators::OpenaiGenerator)
      end
    end

    context 'with valid ollama service' do
      it 'returns an instance of OpenaiGenerator' do
        generator = described_class.create(valid_options_ollama)
        expect(generator).to be_instance_of(Hyrum::Generators::OpenaiGenerator)
      end
    end

    context 'with valid fake service' do
      it 'returns an instance of FakeGenerator' do
        generator = described_class.create(valid_options_fake)
        expect(generator).to be_instance_of(Hyrum::Generators::FakeGenerator)
      end
    end

    context 'with invalid service' do
      it 'raises an ArgumentError' do
        expect { described_class.create(invalid_options) }.to raise_error(ArgumentError, "Invalid AI service: #{invalid_options[:ai_service]}")
      end
    end
  end
end