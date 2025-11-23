# frozen_string_literal: true

module Hyrum
  module Generators
    AI_SERVICES = %i[
      openai anthropic gemini ollama mistral deepseek
      perplexity openrouter vertexai bedrock gpustack fake
    ].freeze

    AI_MODEL_DEFAULTS = {
      openai: :'gpt-4o-mini',
      anthropic: :'claude-haiku-20250514',
      gemini: :'gemini-2.0-flash-exp',
      ollama: :llama3,
      mistral: :'mistral-small-latest',
      deepseek: :'deepseek-chat',
      perplexity: :'llama-3.1-sonar-small-128k-online',
      openrouter: :'openai/gpt-4o-mini',
      vertexai: :'gemini-2.0-flash-exp',
      bedrock: :'anthropic.claude-3-haiku-20240307-v1:0',
      gpustack: :llama3,
      fake: :fake
    }.freeze

    GENERATOR_CLASSES = {
      fake: FakeGenerator
      # All other providers default to AiGenerator
    }.freeze

    class MessageGenerator
      def self.create(options)
        service = options[:ai_service].to_sym

        # Get generator class, defaulting to AiGenerator for unlisted services
        generator_class = GENERATOR_CLASSES.fetch(service, AiGenerator)
        generator_class.new(options)
      end
    end
  end
end
