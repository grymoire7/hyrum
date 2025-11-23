# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Hyrum::Validators::ValidationResult do
  describe '#initialize' do
    it 'creates a result with all fields' do
      result = described_class.new(
        score: 85.5,
        semantic_similarity: 92.0,
        lexical_diversity: 65.0,
        passed: true,
        details: { info: 'test' },
        warnings: ['warning1']
      )

      expect(result.score).to eq(85.5)
      expect(result.semantic_similarity).to eq(92.0)
      expect(result.lexical_diversity).to eq(65.0)
      expect(result.passed).to be true
      expect(result.details).to eq({ info: 'test' })
      expect(result.warnings).to eq(['warning1'])
    end

    it 'defaults warnings to empty array' do
      result = described_class.new(
        score: 85.5,
        semantic_similarity: 92.0,
        lexical_diversity: 65.0,
        passed: true,
        details: {}
      )

      expect(result.warnings).to eq([])
    end

    it 'defaults details to empty hash' do
      result = described_class.new(
        score: 85.5,
        semantic_similarity: 92.0,
        lexical_diversity: 65.0,
        passed: true
      )

      expect(result.details).to eq({})
    end
  end

  describe '#passed?' do
    it 'returns true when passed is true' do
      result = described_class.new(score: 80, semantic_similarity: 90, lexical_diversity: 70, passed: true)
      expect(result.passed?).to be true
    end

    it 'returns false when passed is false' do
      result = described_class.new(score: 50, semantic_similarity: 90, lexical_diversity: 30, passed: false)
      expect(result.passed?).to be false
    end
  end

  describe '#failed?' do
    it 'returns false when passed is true' do
      result = described_class.new(score: 80, semantic_similarity: 90, lexical_diversity: 70, passed: true)
      expect(result.failed?).to be false
    end

    it 'returns true when passed is false' do
      result = described_class.new(score: 50, semantic_similarity: 90, lexical_diversity: 30, passed: false)
      expect(result.failed?).to be true
    end
  end
end
