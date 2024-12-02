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
        generator_class = GENERATOR_CLASSES[options[:ai_service].to_sym]

        # Add error handling for invalid format
        generator_class.new(options)
      end
    end
  end
end
