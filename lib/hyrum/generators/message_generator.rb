# frozen_string_literal: true

module Hyrum
  module Generators
    AI_SERVICES = %i[openai ollama fake].freeze

    AI_MODEL_DEFAULTS = {
      openai: :'gpt-4o-mini',
      ollama: :llama3,
      fake: :fake
    }.freeze

    GENERATOR_CLASSES = {
      openai: OpenaiGenerator,
      ollama: OpenaiGenerator,
      fake: FakeGenerator
    }.freeze

    class MessageGenerator
      def self.create(options)
        unless GENERATOR_CLASSES.key?(options[:ai_service].to_sym)
          raise ArgumentError, "Invalid AI service: #{options[:ai_service]}"
        end

        generator_class = GENERATOR_CLASSES[options[:ai_service].to_sym]
        generator_class.new(options)
      end
    end
  end
end
