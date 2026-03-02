# frozen_string_literal: true

module Hyrum
  module ModelResolver
    class ModelNotFoundError < StandardError; end

    def self.resolve(provider:, family:, strategy: :cheapest)
      models = RubyLLM.models.by_provider(provider).by_family(family)
      raise ModelNotFoundError, "No models found for #{provider}/#{family}" if models.empty?

      selected = case strategy
      when :cheapest then models.min_by(&:input_price_per_million)
      when :newest then models.max_by(&:created_at)
      when :stable then stable(models)
      end

      selected.id.to_sym
    end

    def self.stable(models)
      sorted = models.sort_by(&:created_at)
      sorted[-2] || sorted.last
    end
    private_class_method :stable
  end
end
