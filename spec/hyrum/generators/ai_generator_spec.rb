# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Hyrum::Generators::AiGenerator do
  let(:options) do
    {
      message: 'Server refuses to brew coffee with a teapot',
      key: :e418,
      number: 3,
      ai_service: :openai,
      ai_model: :'gpt-4o-mini',
      verbose: false
    }
  end

  describe '#generate' do
    it 'generates messages via ruby_llm' do
      ai_generated_content = {
        'e418' => [
          'Invalid Brewing Method',
          'Teapot not designed for coffee brewing',
          'Please use a suitable brewing device'
        ]
      }

      # Expected result includes the original message prepended
      expected_result = {
        e418: [
          'Server refuses to brew coffee with a teapot',
          'Invalid Brewing Method',
          'Teapot not designed for coffee brewing',
          'Please use a suitable brewing device'
        ]
      }

      mock_ruby_llm_chat(content: ai_generated_content)

      generator = described_class.new(options)
      result = generator.generate

      expect(result).to eq(expected_result)
    end

    it 'outputs debug info when verbose is true' do
      verbose_options = options.merge(verbose: true)
      expected_content = { 'e418' => ['Message 1'] }

      mock_ruby_llm_chat(content: expected_content)

      generator = described_class.new(verbose_options)

      expect { generator.generate }.to output(/AI response/).to_stdout
    end
  end

  describe 'error handling' do
    it 'handles configuration errors gracefully' do
      error = RubyLLM::ConfigurationError.new('Missing API key')
      mock_ruby_llm_chat(error: error)

      generator = described_class.new(options)

      expect { generator.generate }
        .to output(/Configuration Error.*Missing API key/m).to_stdout
        .and raise_error(SystemExit)
    end

    it 'handles API errors gracefully' do
      error = RubyLLM::RateLimitError.new(nil, 'Rate limit exceeded')
      mock_ruby_llm_chat(error: error)

      generator = described_class.new(options)

      expect { generator.generate }
        .to output(/Error.*Rate limit exceeded/m).to_stdout
        .and raise_error(SystemExit)
    end

    it 'handles general ruby_llm errors gracefully' do
      error = RubyLLM::Error.new(nil, 'Unexpected error')
      mock_ruby_llm_chat(error: error)

      generator = described_class.new(options)

      expect { generator.generate }
        .to output(/Error.*Unexpected error/m).to_stdout
        .and raise_error(SystemExit)
    end
  end

  describe 'provider support' do
    it 'works with anthropic provider' do
      anthropic_options = options.merge(ai_service: :anthropic, ai_model: :'claude-haiku-20250514')
      ai_generated_content = { 'e418' => ['Message 1', 'Message 2', 'Message 3'] }
      expected_result = { e418: ['Server refuses to brew coffee with a teapot', 'Message 1', 'Message 2', 'Message 3'] }

      mock_ruby_llm_chat(content: ai_generated_content)

      generator = described_class.new(anthropic_options)
      result = generator.generate

      expect(result).to eq(expected_result)
      expect(RubyLLM).to have_received(:chat).with(model: 'claude-haiku-20250514', provider: :anthropic)
    end

    it 'works with gemini provider' do
      gemini_options = options.merge(ai_service: :gemini, ai_model: :'gemini-2.0-flash-exp')
      ai_generated_content = { 'e418' => ['Message 1', 'Message 2', 'Message 3'] }
      expected_result = { e418: ['Server refuses to brew coffee with a teapot', 'Message 1', 'Message 2', 'Message 3'] }

      mock_ruby_llm_chat(content: ai_generated_content)

      generator = described_class.new(gemini_options)
      result = generator.generate

      expect(result).to eq(expected_result)
      expect(RubyLLM).to have_received(:chat).with(model: 'gemini-2.0-flash-exp', provider: :gemini)
    end
  end
end
