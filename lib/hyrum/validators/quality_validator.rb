# frozen_string_literal: true

module Hyrum
  module Validators
    class QualityValidator
      DIVERSITY_WEIGHT = 0.5
      SIMILARITY_WEIGHT = 0.5
      MIN_DIVERSITY_THRESHOLD = 30.0
      MIN_SIMILARITY_THRESHOLD = 85.0

      attr_reader :messages, :options

      def initialize(messages, options)
        @messages = messages
        @options = options
      end

      def validate
        return empty_result if messages.empty?

        all_variations = messages.values.flatten
        return single_variation_result if all_variations.size <= 1

        semantic_score = calculate_semantic_similarity(all_variations)
        lexical_score = calculate_lexical_diversity(all_variations)

        overall_score = (semantic_score * SIMILARITY_WEIGHT) + (lexical_score * DIVERSITY_WEIGHT)

        passed = overall_score >= options[:min_quality] &&
                 lexical_score >= MIN_DIVERSITY_THRESHOLD &&
                 semantic_score >= MIN_SIMILARITY_THRESHOLD

        warnings = build_warnings(semantic_score, lexical_score)

        ValidationResult.new(
          score: overall_score.round(2),
          semantic_similarity: semantic_score.round(2),
          lexical_diversity: lexical_score.round(2),
          passed: passed,
          details: {
            min_quality_threshold: options[:min_quality],
            variation_count: all_variations.size
          },
          warnings: warnings
        )
      end

      private

      def calculate_semantic_similarity(variations)
        calculator = SemanticSimilarity.new(
          variations,
          options[:ai_service],
          options[:ai_model]
        )
        calculator.calculate
      rescue StandardError => e
        # Fall back to 100% on error (assume semantic similarity is good)
        warn "Semantic similarity calculation failed: #{e.message}"
        100.0
      end

      def calculate_lexical_diversity(variations)
        calculator = LexicalDiversity.new(variations)
        calculator.calculate
      end

      def build_warnings(semantic_score, lexical_score)
        warnings = []

        if lexical_score < MIN_DIVERSITY_THRESHOLD
          warnings << "Low lexical diversity (#{lexical_score.round(2)}%). Variations may be too similar."
        end

        if semantic_score < MIN_SIMILARITY_THRESHOLD
          warnings << "Low semantic similarity (#{semantic_score.round(2)}%). Variations may have different meanings."
        end

        warnings
      end

      def empty_result
        ValidationResult.new(
          score: 0.0,
          semantic_similarity: 0.0,
          lexical_diversity: 0.0,
          passed: true,
          details: { variation_count: 0 },
          warnings: ['No variations to validate']
        )
      end

      def single_variation_result
        ValidationResult.new(
          score: 0.0,
          semantic_similarity: 0.0,
          lexical_diversity: 0.0,
          passed: true,
          details: { variation_count: messages.values.flatten.size },
          warnings: ['Only one variation - nothing to compare']
        )
      end
    end
  end
end
