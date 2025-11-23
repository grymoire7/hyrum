# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Hyrum::Validators::SemanticSimilarity do
  let(:mock_embeddings) do
    {
      'Server error' => [1.0, 0.0, 0.0],
      'Server problem' => [0.95, 0.05, 0.0],
      'Connection timeout' => [0.3, 0.7, 0.0]
    }
  end

  describe '#calculate' do
    it 'returns high similarity for semantically similar variations' do
      variations = ['Server error', 'Server problem']
      calculator = described_class.new(variations, :fake, :fake)

      allow(calculator).to receive(:supports_embeddings?).and_return(true)
      allow(calculator).to receive(:get_embeddings).and_return(
        mock_embeddings.values_at(*variations)
      )

      score = calculator.calculate
      expect(score).to be > 85.0
    end

    it 'returns low similarity for semantically different variations' do
      variations = ['Server error', 'Connection timeout']
      calculator = described_class.new(variations, :fake, :fake)

      allow(calculator).to receive(:supports_embeddings?).and_return(true)
      allow(calculator).to receive(:get_embeddings).and_return(
        mock_embeddings.values_at(*variations)
      )

      score = calculator.calculate
      expect(score).to be < 60.0
    end

    it 'returns 100 for identical variations' do
      variations = ['Server error', 'Server error']
      calculator = described_class.new(variations, :fake, :fake)

      allow(calculator).to receive(:supports_embeddings?).and_return(true)
      allow(calculator).to receive(:get_embeddings).and_return(
        [mock_embeddings['Server error'], mock_embeddings['Server error']]
      )

      expect(calculator.calculate).to eq(100.0)
    end

    it 'handles single variation' do
      variations = ['Server error']
      calculator = described_class.new(variations, :fake, :fake)
      expect(calculator.calculate).to eq(100.0)
    end

    it 'handles empty variations' do
      variations = []
      calculator = described_class.new(variations, :fake, :fake)
      expect(calculator.calculate).to eq(100.0)
    end

    it 'uses fallback for providers without embeddings' do
      variations = ['Server error', 'Server problem', 'Server issue']
      calculator = described_class.new(variations, :fake, :fake)

      allow(calculator).to receive(:supports_embeddings?).and_return(false)

      score = calculator.calculate
      expect(score).to be_between(0.0, 100.0)
    end
  end

  describe '#supports_embeddings?' do
    it 'returns true for OpenAI' do
      calculator = described_class.new([], :openai, :'gpt-4o-mini')
      expect(calculator.supports_embeddings?).to be true
    end

    it 'returns false for Anthropic' do
      calculator = described_class.new([], :anthropic, :'claude-haiku-20250514')
      expect(calculator.supports_embeddings?).to be false
    end

    it 'returns false for fake' do
      calculator = described_class.new([], :fake, :fake)
      expect(calculator.supports_embeddings?).to be false
    end
  end
end
