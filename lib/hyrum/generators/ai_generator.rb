# frozen_string_literal: true

require 'ruby_llm'

module Hyrum
  module Generators
    class AiGenerator
      API_KEY_ENV_VARS = {
        openai: 'OPENAI_API_KEY',
        anthropic: 'ANTHROPIC_API_KEY',
        gemini: 'GEMINI_API_KEY',
        ollama: 'OLLAMA_API_BASE',
        vertexai: 'GOOGLE_CLOUD_PROJECT',
        bedrock: 'AWS_ACCESS_KEY_ID',
        deepseek: 'DEEPSEEK_API_KEY',
        mistral: 'MISTRAL_API_KEY',
        perplexity: 'PERPLEXITY_API_KEY',
        openrouter: 'OPENROUTER_API_KEY',
        gpustack: 'GPUSTACK_API_KEY'
      }.freeze

      attr_reader :options

      def initialize(options)
        @options = options
      end

      def generate
        response = chat.ask(prompt)
        puts "AI response: #{response.inspect}" if options[:verbose]

        # Prepend the original message to the generated variations
        # RubyLLM returns string keys, but our options use symbols
        result = response.content.dup
        key_str = options[:key].to_s
        if result[key_str].is_a?(Array)
          result[key_str] = [options[:message]] + result[key_str]
        end

        # Convert string keys to symbols for consistency with the rest of hyrum
        result.transform_keys(&:to_sym)
      rescue RubyLLM::ConfigurationError => e
        handle_configuration_error(e)
      rescue RubyLLM::Error => e
        handle_general_error(e)
      end

      private

      def chat
        @chat ||= RubyLLM.chat(
          model: options[:ai_model].to_s,
          provider: options[:ai_service]
        ).with_schema(response_schema)
      end

      def prompt
        <<~PROMPT
          Please provide #{options[:number]} alternative status messages for the following message:
          "#{options[:message]}"

          The messages should be unique and informative.
        PROMPT
      end

      # rubocop:disable Metrics/MethodLength
      def response_schema
        {
          type: 'object',
          properties: {
            options[:key] => {
              type: 'array',
              items: { type: 'string' },
              minItems: options[:number],
              maxItems: options[:number]
            }
          },
          required: [options[:key].to_s],
          additionalProperties: false
        }
      end
      # rubocop:enable Metrics/MethodLength

      def handle_configuration_error(error)
        puts "Configuration Error: #{error.message}"
        puts "Please set the required API key for #{options[:ai_service]}."
        puts "Example: export #{api_key_env_var_name}=your-key-here"
        exit 1
      end

      def handle_general_error(error)
        puts "Error: #{error.message}"
        puts 'Please check your configuration and try again.'
        exit 1
      end

      def api_key_env_var_name
        API_KEY_ENV_VARS.fetch(options[:ai_service], "#{options[:ai_service].to_s.upcase}_API_KEY")
      end
    end
  end
end
