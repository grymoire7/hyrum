# frozen_string_literal: true

require 'set'

module Hyrum
  module Validators
    class LexicalDiversity
      attr_reader :variations

      def initialize(variations)
        @variations = variations
      end

      def calculate
        return 0.0 if variations.empty? || variations.size == 1

        # Calculate average pairwise Jaccard distance
        distances = []
        variations.combination(2).each do |var1, var2|
          distances << jaccard_distance(tokenize(var1), tokenize(var2))
        end

        # Convert to percentage (0-100)
        (distances.sum / distances.size * 100).round(2)
      end

      private

      def tokenize(text)
        # Convert to lowercase and split into words, removing punctuation
        text.downcase.scan(/\w+/).to_set
      end

      def jaccard_distance(set1, set2)
        # Jaccard distance = 1 - Jaccard similarity
        # Jaccard similarity = intersection / union
        return 1.0 if set1.empty? && set2.empty?
        return 1.0 if set1.union(set2).empty?

        intersection = set1.intersection(set2).size.to_f
        union = set1.union(set2).size.to_f
        1.0 - (intersection / union)
      end
    end
  end
end
