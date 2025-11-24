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
      variations = { status: ['Error 1', 'Error 2', 'Error 3'] }
      validator = described_class.new(variations, options)
      result = validator.validate

      expect(result).to be_a(Hyrum::Validators::ValidationResult)
    end

    it 'calculates scores for variations' do
      variations = { status: ['Error occurred', 'Problem detected', 'Issue found'] }
      validator = described_class.new(variations, options)
      result = validator.validate

      expect(result.score).to be_between(0.0, 100.0)
      expect(result.semantic_similarity).to be_between(0.0, 100.0)
      expect(result.lexical_diversity).to be_between(0.0, 100.0)
    end

    it 'fails when lexical diversity threshold not met' do
      # Use nearly identical variations
      variations = { status: ['Error', 'Error', 'Error'] }
      validator = described_class.new(variations, options)
      result = validator.validate

      expect(result.lexical_diversity).to eq(0.0)
      expect(result.passed?).to be false
      expect(result.warnings).not_to be_empty
    end

    it 'fails when semantic similarity threshold not met' do
      # Use completely different words for low semantic similarity
      variations = { status: ['Alpha', 'Bravo', 'Charlie'] }
      validator = described_class.new(variations, options)
      result = validator.validate

      expect(result.semantic_similarity).to be < 85
      expect(result.passed?).to be false
    end

    it 'adds warnings for threshold violations' do
      # Test that warnings are generated
      variations = { status: ['X', 'X', 'X'] }
      validator = described_class.new(variations, options)
      result = validator.validate

      expect(result.warnings).not_to be_empty
    end

    it 'handles multiple message keys' do
      variations = {
        status: ['Error occurred', 'Problem detected'],
        warning: ['Caution advised', 'Warning issued']
      }
      validator = described_class.new(variations, options)
      result = validator.validate

      expect(result).to be_a(Hyrum::Validators::ValidationResult)
    end

    it 'handles single variation gracefully' do
      variations = { status: ['Server error'] }
      validator = described_class.new(variations, options)
      result = validator.validate

      expect(result.passed?).to be true
      expect(result.warnings).to include(match(/one variation/i))
    end

    it 'handles empty variations gracefully' do
      variations = {}
      validator = described_class.new(variations, options)
      result = validator.validate

      expect(result.passed?).to be true
      expect(result.warnings).to include(match(/no variations/i))
    end
  end
end
