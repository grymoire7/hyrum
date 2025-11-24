# frozen_string_literal: true

require 'matrix'
require 'set'

module Hyrum
  module Validators
    class SemanticSimilarity
      attr_reader :original_message, :variations, :ai_service, :ai_model

      def initialize(original_message, variations, ai_service, ai_model)
        @original_message = original_message
        @variations = variations
        @ai_service = ai_service
        @ai_model = ai_model
      end

      def calculate
        return 100.0 if variations.empty?

        if supports_embeddings?
          calculate_with_embeddings
        else
          calculate_with_fallback
        end
      end

      def supports_embeddings?
        # Check if RubyLLM has any embedding models available in the current registry
        # User is responsible for calling RubyLLM.models.refresh! if needed
        RubyLLM.models.embedding_models.any?
      rescue StandardError
        # If we can't check the registry, assume embeddings aren't available
        false
      end

      private

      def calculate_with_embeddings
        # Batch all texts together for efficient API call
        all_texts = [original_message] + variations
        all_embeddings = get_embeddings(all_texts)

        # First embedding is the original, rest are variations
        original_embedding = all_embeddings.first
        variation_embeddings = all_embeddings[1..]

        # Compare each variation to the original message
        similarities = variation_embeddings.map do |var_embedding|
          cosine_similarity(original_embedding, var_embedding)
        end

        # Convert to percentage (0-100)
        (similarities.sum / similarities.size * 100).round(2)
      end

      def calculate_with_fallback
        # Simple word overlap heuristic when embeddings not available
        original_words = original_message.downcase.scan(/\w+/).to_set

        # Compare each variation to the original message
        similarities = variations.map do |variation|
          var_words = variation.downcase.scan(/\w+/).to_set
          intersection = original_words.intersection(var_words).size.to_f
          union = original_words.union(var_words).size.to_f
          union.zero? ? 1.0 : intersection / union
        end

        (similarities.sum / similarities.size * 100).round(2)
      end

      def get_embeddings(texts)
        # Use RubyLLM.embed with user's configured default embedding model
        # Works with any provider (OpenAI, Google, Anthropic, etc.)
        result = RubyLLM.embed(texts)

        # RubyLLM.embed returns a single result with vectors array
        result.vectors
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
