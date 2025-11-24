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
      # Mock returns all embeddings in one batch: [original, var1, var2]
      allow(calculator).to receive(:get_embeddings).with([original] + variations).and_return(
        [mock_embeddings[original], mock_embeddings['Server problem'], mock_embeddings['Server issue']]
      )

      score = calculator.calculate
      expect(score).to be > 85.0
    end

    it 'returns low similarity when variations differ from original message' do
      original = 'Server error'
      variations = ['Connection timeout', 'Connection timeout']
      calculator = described_class.new(original, variations, :fake, :fake)

      allow(calculator).to receive(:supports_embeddings?).and_return(true)
      # Mock returns all embeddings in one batch: [original, var1, var2]
      allow(calculator).to receive(:get_embeddings).with([original] + variations).and_return(
        [mock_embeddings[original], mock_embeddings['Connection timeout'], mock_embeddings['Connection timeout']]
      )

      score = calculator.calculate
      expect(score).to be < 60.0
    end

    it 'returns 100 when variation is identical to original' do
      original = 'Server error'
      variations = ['Server error']
      calculator = described_class.new(original, variations, :fake, :fake)

      allow(calculator).to receive(:supports_embeddings?).and_return(true)
      # Mock returns all embeddings in one batch: [original, var1]
      allow(calculator).to receive(:get_embeddings).with([original] + variations).and_return(
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
    it 'returns true when embedding models are available in registry' do
      calculator = described_class.new('test', [], :openai, :'gpt-4o-mini')

      # Mock the model registry to have embedding models
      allow(RubyLLM.models).to receive(:embedding_models).and_return([:some_model])

      expect(calculator.supports_embeddings?).to be true
    end

    it 'returns false when no embedding models in registry' do
      calculator = described_class.new('test', [], :anthropic, :'claude-haiku-20250514')

      # Mock the model registry to have no embedding models
      allow(RubyLLM.models).to receive(:embedding_models).and_return([])

      expect(calculator.supports_embeddings?).to be false
    end

    it 'returns false when registry check fails' do
      calculator = described_class.new('test', [], :fake, :fake)

      # Mock a registry error
      allow(RubyLLM.models).to receive(:embedding_models).and_raise(StandardError)

      expect(calculator.supports_embeddings?).to be false
    end
  end
end
