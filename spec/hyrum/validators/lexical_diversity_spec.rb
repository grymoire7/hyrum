# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Hyrum::Validators::LexicalDiversity do
  describe '#calculate' do
    it 'returns 0 for identical variations' do
      variations = ['Server error', 'Server error', 'Server error']
      calculator = described_class.new(variations)
      expect(calculator.calculate).to eq(0.0)
    end

    it 'returns high score for completely different variations' do
      variations = ['Server error', 'Connection timeout', 'Request failed']
      calculator = described_class.new(variations)
      score = calculator.calculate
      expect(score).to be > 70.0
    end

    it 'returns moderate score for partially different variations' do
      variations = ['Server error occurred', 'Server error detected', 'Server problem occurred']
      calculator = described_class.new(variations)
      score = calculator.calculate
      expect(score).to be_between(30.0, 70.0)
    end

    it 'returns low score for trivially different variations' do
      variations = ['Server error', 'Server error occurred', 'A server error']
      calculator = described_class.new(variations)
      score = calculator.calculate
      expect(score).to be < 40.0
    end

    it 'handles single variation' do
      variations = ['Server error']
      calculator = described_class.new(variations)
      expect(calculator.calculate).to eq(0.0)
    end

    it 'handles empty variations' do
      variations = []
      calculator = described_class.new(variations)
      expect(calculator.calculate).to eq(0.0)
    end

    it 'is case-insensitive' do
      variations = ['Server Error', 'server error', 'SERVER ERROR']
      calculator = described_class.new(variations)
      expect(calculator.calculate).to eq(0.0)
    end
  end
end
