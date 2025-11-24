# frozen_string_literal: true

require 'optparse'
require 'zeitwerk'
require 'dry-struct'
require 'dry-validation'
require 'ruby_llm'

# Configure RubyLLM with environment variables
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY'] if ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY'] if ENV['ANTHROPIC_API_KEY']
  config.gemini_api_key = ENV['GEMINI_API_KEY'] if ENV['GEMINI_API_KEY']
  config.mistral_api_key = ENV['MISTRAL_API_KEY'] if ENV['MISTRAL_API_KEY']
  config.deepseek_api_key = ENV['DEEPSEEK_API_KEY'] if ENV['DEEPSEEK_API_KEY']
  config.perplexity_api_key = ENV['PERPLEXITY_API_KEY'] if ENV['PERPLEXITY_API_KEY']
  config.openrouter_api_key = ENV['OPENROUTER_API_KEY'] if ENV['OPENROUTER_API_KEY']
  config.ollama_api_base = ENV['OLLAMA_API_BASE'] if ENV['OLLAMA_API_BASE']
  config.gpustack_api_base = ENV['GPUSTACK_API_BASE'] if ENV['GPUSTACK_API_BASE']
  config.gpustack_api_key = ENV['GPUSTACK_API_KEY'] if ENV['GPUSTACK_API_KEY']
end

loader = Zeitwerk::Loader.for_gem
loader.setup

module Types
  include Dry.Types()
end

class CLIOptions < Dry::Struct
  attribute :message, Types::String.optional
  attribute :key, Types::Coercible::Symbol.default(:status)
  attribute :ai_service, Types::Coercible::Symbol.default(:fake)
  attribute :ai_model, Types::Coercible::Symbol
  attribute :number, Types::Integer.default(5)
  attribute :format, Types::Coercible::Symbol.default(:text)
  attribute :verbose, Types::Bool.default(false)
  attribute :validate, Types::Bool.default(false)
  attribute :min_quality, Types::Integer.default(70)
  attribute :strict, Types::Bool.default(false)
  attribute :show_scores, Types::Bool.default(false)

  def self.build_and_validate(input)
    # apply defaults and coercions
    cli_options = new(input)

    # validate the options
    contract_result = CLIOptionsContract.new.call(cli_options.to_h)

    if contract_result.errors.any?
      error_messages = contract_result.errors.to_h.map do |key, errors|
        error_text = errors.is_a?(Array) ? errors.join(', ') : errors
        "Error with #{key}: #{error_text}"
      end
      raise Hyrum::ScriptOptionsError, error_messages.join("\n")
    end

    contract_result
  end
end

class GeneratorOptions < Dry::Struct
  attribute :message, Types::String.optional
  attribute :key, Types::Coercible::Symbol
  attribute :ai_service, Types::Coercible::Symbol
  attribute :ai_model, Types::Coercible::Symbol
  attribute :number, Types::Integer
  attribute :verbose, Types::Bool

  def self.from_parent(parent)
    new(parent.to_h.slice(:message, :key, :ai_service, :ai_model, :number, :verbose))
  end
end

class FormatterOptions < Dry::Struct
  attribute :format, Types::Coercible::Symbol
  attribute :verbose, Types::Bool
  attribute :show_scores, Types::Bool

  def self.from_parent(parent)
    new(parent.to_h.slice(:format, :verbose, :show_scores))
  end
end

class ValidatorOptions < Dry::Struct
  attribute :validate, Types::Bool
  attribute :min_quality, Types::Integer
  attribute :strict, Types::Bool
  attribute :ai_service, Types::Coercible::Symbol
  attribute :ai_model, Types::Coercible::Symbol

  def self.from_parent(parent)
    new(parent.to_h.slice(:validate, :min_quality, :strict, :ai_service, :ai_model))
  end
end

class CLIOptionsContract < Dry::Validation::Contract
  params do
    required(:key).value(:symbol)
    required(:ai_service).value(:symbol)
    required(:ai_model).value(:symbol)
    required(:number).value(:integer)
    required(:format).value(:symbol)
    optional(:verbose).value(:bool)
    optional(:message).maybe(:string)
    optional(:validate).value(:bool)
    optional(:min_quality).value(:integer)
    optional(:strict).value(:bool)
    optional(:show_scores).value(:bool)
  end

  rule(:number) do
    key.failure('must be > 0') if value && value <= 0
  end

  rule(:min_quality) do
    key.failure('must be between 0 and 100') if value && (value < 0 || value > 100)
  end
end

module Hyrum
  # rubocop:disable Metrics/MethodLength
  def self.run(args)
    parsed_options = ScriptOptions.new(args).parse
    options = CLIOptions.build_and_validate(parsed_options)

    generator_options = GeneratorOptions.from_parent(options)
    formatter_options = FormatterOptions.from_parent(options)
    validator_options = ValidatorOptions.from_parent(options)

    if options[:verbose]
      puts "Options: #{options.inspect}"
      puts "Generator Options: #{generator_options.inspect}"
      puts "Formatter Options: #{formatter_options.inspect}"
      puts "Validator Options: #{validator_options.inspect}"
    end

    # Generate messages
    formatter = Formats::Formatter.new(formatter_options)
    message_generator = Generators::MessageGenerator.create(generator_options)
    messages = message_generator.generate

    # Validate if requested
    validation_result = nil
    if validator_options[:validate]
      validator = Validators::QualityValidator.new(
        options[:message],
        messages,
        validator_options.to_h
      )
      validation_result = validator.validate

      if validation_result.failed? && validator_options[:strict]
        warn "Quality validation failed:"
        warn "  Score: #{validation_result.score}/100"
        warn "  Semantic similarity: #{validation_result.semantic_similarity}%"
        warn "  Lexical diversity: #{validation_result.lexical_diversity}%"
        validation_result.warnings.each { |w| warn "  - #{w}" }
        exit 1
      end
    end

    # Format and output
    output = formatter.format(messages, validation_result)
    puts output
  rescue ScriptOptionsError => e
    puts e.message
    exit 1
  end
  # rubocop:enable Metrics/MethodLength
end

loader.eager_load
