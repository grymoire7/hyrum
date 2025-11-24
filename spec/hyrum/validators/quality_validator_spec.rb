# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Hyrum::Validators::QualityValidator do
  let(:options) do
    {
      min_quality: 70,
      ai_service: :fake,
      ai_model: :fake
    }
  end

  describe '#validate' do
    it 'returns a ValidationResult' do
      original_message = 'Server error'
      variations = { status: ['Server problem', 'Server issue', 'Server failure'] }
      validator = described_class.new(original_message, variations, options)
      result = validator.validate

      expect(result).to be_a(Hyrum::Validators::ValidationResult)
    end

    it 'calculates scores for variations' do
      original_message = 'Error occurred'
      variations = { status: ['Problem detected', 'Issue found', 'Failure encountered'] }
      validator = described_class.new(original_message, variations, options)
      result = validator.validate

      expect(result.score).to be_between(0.0, 100.0)
      expect(result.semantic_similarity).to be_between(0.0, 100.0)
      expect(result.lexical_diversity).to be_between(0.0, 100.0)
    end

    it 'fails when lexical diversity threshold not met' do
      original_message = 'Error'
      # Use nearly identical variations (low diversity)
      variations = { status: ['Error', 'Error', 'Error'] }
      validator = described_class.new(original_message, variations, options)
      result = validator.validate

      expect(result.lexical_diversity).to eq(0.0)
      expect(result.passed?).to be false
      expect(result.warnings).not_to be_empty
    end

    it 'fails when semantic similarity threshold not met' do
      original_message = 'Server error'
      # Use completely different messages (low similarity to original)
      variations = { status: ['Alpha', 'Bravo', 'Charlie'] }
      validator = described_class.new(original_message, variations, options)
      result = validator.validate

      expect(result.semantic_similarity).to be < 85
      expect(result.passed?).to be false
    end

    it 'adds warnings for threshold violations' do
      original_message = 'Test'
      # Test that warnings are generated
      variations = { status: ['X', 'X', 'X'] }
      validator = described_class.new(original_message, variations, options)
      result = validator.validate

      expect(result.warnings).not_to be_empty
    end

    it 'handles multiple message keys' do
      original_message = 'Error occurred'
      variations = {
        status: ['Problem detected', 'Issue found'],
        warning: ['Caution advised', 'Warning issued']
      }
      validator = described_class.new(original_message, variations, options)
      result = validator.validate

      expect(result).to be_a(Hyrum::Validators::ValidationResult)
    end

    it 'handles single variation gracefully' do
      original_message = 'Server error'
      variations = { status: ['Server problem'] }
      validator = described_class.new(original_message, variations, options)
      result = validator.validate

      expect(result.passed?).to be true
      expect(result.warnings).to include(match(/one variation/i))
    end

    it 'handles empty variations gracefully' do
      original_message = 'Test message'
      variations = {}
      validator = described_class.new(original_message, variations, options)
      result = validator.validate

      expect(result.passed?).to be true
      expect(result.warnings).to include(match(/no variations/i))
    end
  end
end
