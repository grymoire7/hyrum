# frozen_string_literal: true

module Hyrum
  module Validators
    class ValidationResult < Dry::Struct
      attribute :score, Types::Coercible::Float
      attribute :semantic_similarity, Types::Coercible::Float
      attribute :lexical_diversity, Types::Coercible::Float
      attribute :passed, Types::Bool
      attribute :details, Types::Hash.default({}.freeze)
      attribute :warnings, Types::Array.of(Types::String).default([].freeze)

      def passed?
        passed
      end

      def failed?
        !passed
      end
    end
  end
end
