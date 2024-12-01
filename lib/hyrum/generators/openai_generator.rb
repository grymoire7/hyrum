# frozen_string_literal: true

require 'openai'
require 'json'
require 'erb'

module Hyrum
  module Generators
    class OpenaiGenerator
      attr_reader :options

      def initialize(options)
        @options = options
        configure
        @client = OpenAI::Client.new
      end

      def generate
        if @options[:ai_model] == 'fake'
          return JSON.parse(canned_content)
        end

        response = get_response(prompt)
        puts "Response: #{JSON.pretty_generate(response)}" if @options[:verbose]
        content = response.dig('choices', 0, 'message', 'content')
        JSON.parse(content)
      end

      private

      def prompt
        prompt = <<~PROMPT
          Please provide 5 alternative status messages for the following message:
          `<%= message %>`. The messages should be unique and informative. The messages
          should be returned as json in the format: `{ "<%= key %>": ['list', 'of', 'messages']}`
          The key should be `"<%= key %>"` followed by the list of messages.
        PROMPT
        erb_hash = { key: @options[:key], message: @options[:message] }
        template = ERB.new(prompt, trim_mode: '-')
        template.result_with_hash(erb_hash)
      end

      def get_response(prompt)
        @client.chat(
          parameters: {
            model: @options[:ai_model],
            response_format: { type: 'json_object' },
            messages: [{ role: 'user', content: prompt}],
            temperature: 0.7
          }
        )
      end

      def configure
        OpenAI.configure do |config|
          config.access_token = ENV.fetch('OPENAI_ACCESS_TOKEN') if options[:ai_service] == :openai
          # config.log_errors = true # Use for development
          config.organization_id = ENV['OPENAI_ORGANIZATION_ID'] if ENV['OPENAI_ORGANIZATION_ID']
          config.request_timeout = 240
          if options[:ai_service] == :ollama
            config.uri_base = ENV['OLLAMA_URL'] || 'http://localhost:11434'
          end
        end
      rescue KeyError => e
        puts "Error: #{e.message}"
        puts "Please set the OPENAI_ACCESS_TOKEN environment variable."
        exit
      end

      def canned_content
        FakeGenerator::FAKE_MESSAGES
      end
    end
  end
end
