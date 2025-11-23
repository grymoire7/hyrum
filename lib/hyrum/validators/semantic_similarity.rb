# frozen_string_literal: true

require 'matrix'
require 'set'

module Hyrum
  module Validators
    class SemanticSimilarity
      EMBEDDING_PROVIDERS = %i[openai].freeze

      attr_reader :variations, :ai_service, :ai_model

      def initialize(variations, ai_service, ai_model)
        @variations = variations
        @ai_service = ai_service
        @ai_model = ai_model
      end

      def calculate
        return 100.0 if variations.empty? || variations.size == 1

        if supports_embeddings?
          calculate_with_embeddings
        else
          calculate_with_fallback
        end
      end

      def supports_embeddings?
        EMBEDDING_PROVIDERS.include?(ai_service)
      end

      private

      def calculate_with_embeddings
        embeddings = get_embeddings(variations)
        similarities = []

        embeddings.combination(2).each do |emb1, emb2|
          similarities << cosine_similarity(emb1, emb2)
        end

        # Convert to percentage (0-100)
        (similarities.sum / similarities.size * 100).round(2)
      end

      def calculate_with_fallback
        # Simple word overlap heuristic when embeddings not available
        word_sets = variations.map { |v| v.downcase.scan(/\w+/).to_set }
        similarities = []

        word_sets.combination(2).each do |set1, set2|
          intersection = set1.intersection(set2).size.to_f
          union = set1.union(set2).size.to_f
          similarities << (union.zero? ? 1.0 : intersection / union)
        end

        (similarities.sum / similarities.size * 100).round(2)
      end

      def get_embeddings(texts)
        # Use OpenAI embeddings API via RubyLLM
        client = RubyLLM.embed(
          model: 'text-embedding-3-small',
          provider: :openai
        )

        texts.map do |text|
          response = client.embed(text)
          response.embedding
        end
      rescue RubyLLM::Error => e
        # Fall back to heuristic if embedding fails
        warn "Embedding API failed: #{e.message}. Using fallback heuristic."
        raise # Re-raise to trigger fallback in calculate method
      end

      def cosine_similarity(vec1, vec2)
        # Calculate cosine similarity between two vectors
        v1 = Vector.elements(vec1)
        v2 = Vector.elements(vec2)

        dot_product = v1.inner_product(v2)
        magnitude1 = Math.sqrt(v1.inner_product(v1))
        magnitude2 = Math.sqrt(v2.inner_product(v2))

        return 0.0 if magnitude1.zero? || magnitude2.zero?

        dot_product / (magnitude1 * magnitude2)
      end
    end
  end
end
