require 'spec_helper'

RSpec.describe Hyrum::Generators::OpenaiGenerator do
  let(:options) do
    {
      message: 'This is a test message',
      key: 'key',
      ai_service: :openai,
      ai_model: 'gpt-4o-mini',
      verbose: false
    }
  end
  let(:fake_content) { Hyrum::Generators::FakeGenerator::FAKE_MESSAGES }
  let(:fake_response) do
    {
      'choices' => [
        {
          'message' => {
            'content' => JSON.generate(
              {
                'key' => ['message 1', 'message2', 'message3']
              }
            )
          }
        }
      ]
    }
  end

  subject { described_class.new(options) }

  describe '#initialize' do
    it 'sets the options' do
      expect(subject.options).to eq(options)
    end
  end

  describe '#generate' do
    before do
      allow(subject).to receive(:get_response).and_return(fake_response)
    end

    context 'when the ai_model is fake' do
      let(:options) { super().merge(ai_model: 'fake') }

      it 'returns fake content' do
        expected = JSON.parse(fake_content)
        expect(subject.generate).to eq(expected)
      end
    end

    context 'when the ai_model is not fake' do
      it 'calls get_response' do
        expect(subject).to receive(:get_response)
        subject.generate
      end
    end
  end
end
