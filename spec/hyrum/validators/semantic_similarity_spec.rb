# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Hyrum::Validators::SemanticSimilarity do
  let(:mock_embeddings) do
    {
      'Server error' => [1.0, 0.0, 0.0],
      'Server problem' => [0.95, 0.05, 0.0],
      'Server issue' => [0.92, 0.08, 0.0],
      'Connection timeout' => [0.3, 0.7, 0.0]
    }
  end

  describe '#calculate' do
    it 'returns high similarity when variations match original message' do
      original = 'Server error'
      variations = ['Server problem', 'Server issue']
      calculator = described_class.new(original, variations, :fake, :fake)

      allow(calculator).to receive(:supports_embeddings?).and_return(true)
      allow(calculator).to receive(:get_embeddings).and_return(
        [mock_embeddings[original]] + mock_embeddings.values_at(*variations)
      )

      score = calculator.calculate
      expect(score).to be > 85.0
    end

    it 'returns low similarity when variations differ from original message' do
      original = 'Server error'
      variations = ['Connection timeout', 'Connection timeout']
      calculator = described_class.new(original, variations, :fake, :fake)

      allow(calculator).to receive(:supports_embeddings?).and_return(true)
      allow(calculator).to receive(:get_embeddings).and_return(
        [mock_embeddings[original]] + mock_embeddings.values_at(*variations)
      )

      score = calculator.calculate
      expect(score).to be < 60.0
    end

    it 'returns 100 when variation is identical to original' do
      original = 'Server error'
      variations = ['Server error']
      calculator = described_class.new(original, variations, :fake, :fake)

      allow(calculator).to receive(:supports_embeddings?).and_return(true)
      allow(calculator).to receive(:get_embeddings).and_return(
        [mock_embeddings[original], mock_embeddings[original]]
      )

      expect(calculator.calculate).to eq(100.0)
    end

    it 'handles empty variations' do
      original = 'Server error'
      variations = []
      calculator = described_class.new(original, variations, :fake, :fake)
      expect(calculator.calculate).to eq(100.0)
    end

    it 'uses fallback for providers without embeddings' do
      original = 'Server error'
      variations = ['Server problem', 'Server issue', 'Server failure']
      calculator = described_class.new(original, variations, :fake, :fake)

      allow(calculator).to receive(:supports_embeddings?).and_return(false)

      score = calculator.calculate
      expect(score).to be_between(0.0, 100.0)
    end
  end

  describe '#supports_embeddings?' do
    it 'returns true for OpenAI' do
      calculator = described_class.new('test', [], :openai, :'gpt-4o-mini')
      expect(calculator.supports_embeddings?).to be true
    end

    it 'returns false for Anthropic' do
      calculator = described_class.new('test', [], :anthropic, :'claude-haiku-20250514')
      expect(calculator.supports_embeddings?).to be false
    end

    it 'returns false for fake' do
      calculator = described_class.new('test', [], :fake, :fake)
      expect(calculator.supports_embeddings?).to be false
    end
  end
end
