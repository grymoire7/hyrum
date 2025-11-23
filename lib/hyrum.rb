# frozen_string_literal: true

require 'optparse'
require 'zeitwerk'
require 'dry-struct'
require 'dry-validation'
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

    if options[:verbose]
      puts "Options: #{options.inspect}"
      puts "Generator Options: #{generator_options.inspect}"
      puts "Formatter Options: #{formatter_options.inspect}"
    end

    formatter = Formats::Formatter.new(formatter_options)
    message_generator = Generators::MessageGenerator.create(generator_options)
    messages = message_generator.generate
    output = formatter.format(messages)
    puts output
  rescue ScriptOptionsError => e
    puts e.message
    exit 1
  end
  # rubocop:enable Metrics/MethodLength
end

loader.eager_load
