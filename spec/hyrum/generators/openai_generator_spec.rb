require 'spec_helper'

RSpec.describe Hyrum::Generators::OpenaiGenerator do
  let(:options) do
    {
      message: 'This is a test message',
      key: :key,
      ai_service: :openai,
      ai_model: :'gpt-4o-mini',
      verbose: false
    }
  end
  let(:canned_content) { Hyrum::Generators::FakeGenerator::FAKE_MESSAGES }
  let(:canned_response) do
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
      allow(subject).to receive(:chat_response).and_return(canned_response)
    end

    context 'when the ai_service is openai' do
      context 'when an access token is provided' do
        before(:each) do
          ENV['OPENAI_ACCESS_TOKEN'] = 'fake_token'
        end

        it 'calls chat_response' do
          # allow(OpenAI::Client).to receive(:chat).and_return(canned_response)
          expect(subject).to receive(:chat_response)
          subject.generate
        end
      end

      context 'when an access token is not provided' do
        before do
          ENV.delete('OPENAI_ACCESS_TOKEN')
        end

        it 'does not call chat_response' do
          expect(subject).not_to receive(:chat_response)
          expect { subject.generate }
        end

        it 'exits with an error' do
          expect { subject.generate }.to raise_error(SystemExit)
        end
      end
    end

    context 'when the ai_service is ollama' do
      let(:options) { super().merge(ai_service: :ollama) }

      it 'calls chat_response' do
        expect(subject).to receive(:chat_response)
        subject.generate
      end
    end
  end
end
