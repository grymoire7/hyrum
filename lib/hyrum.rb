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

  def self.build_and_validate(input)
    # apply defaults and coercions
    cli_options = new(input)

    # validate the options
    contract_result = CLIOptionsContract.new.call(cli_options.to_h)

    if contract_result.errors.any?
      error_message = contract_result.errors.to_h.each_with_object('') do |key, errors, err_str|
        err_str << "Error with #{key}: #{errors.join(', ')}\n"
      end
      raise ScriptOptionsError, error_message
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

  def self.from_parent(parent)
    new(parent.to_h.slice(:format, :verbose))
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
  end

  rule(:number) do
    key.failure('must be > 0') if value && value <= 0
  end
end

module Hyrum
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
end

loader.eager_load
