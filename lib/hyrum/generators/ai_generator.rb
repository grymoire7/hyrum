# frozen_string_literal: true

require 'ruby_llm'

module Hyrum
  module Generators
    class AiGenerator
      attr_reader :options

      def initialize(options)
        @options = options
      end

      def generate
        response = chat.ask(prompt)
        puts "AI response: #{response.inspect}" if options[:verbose]
        response.content
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
        case options[:ai_service]
        when :openai then 'OPENAI_API_KEY'
        when :anthropic then 'ANTHROPIC_API_KEY'
        when :gemini then 'GEMINI_API_KEY'
        when :ollama then 'OLLAMA_API_BASE'
        when :vertexai then 'GOOGLE_CLOUD_PROJECT'
        when :bedrock then 'AWS_ACCESS_KEY_ID'
        when :deepseek then 'DEEPSEEK_API_KEY'
        when :mistral then 'MISTRAL_API_KEY'
        when :perplexity then 'PERPLEXITY_API_KEY'
        when :openrouter then 'OPENROUTER_API_KEY'
        when :gpustack then 'GPUSTACK_API_KEY'
        else "#{options[:ai_service].to_s.upcase}_API_KEY"
        end
      end
    end
  end
end
