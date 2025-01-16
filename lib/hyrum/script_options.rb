# frozen_string_literal: true

require 'optparse'

module Hyrum
  class ScriptOptionsError < StandardError; end

  class ScriptOptions
    MANDATORY_OPTIONS = %i[message].freeze

    attr_reader :options

    def initialize(args)
      @options = {}
      @args = args
    end

    def parse
      OptionParser.new do |parser|
        define_options(parser)
        parser.parse!(@args)
      end
      enforce_mandatory_options
      set_dynamic_defaults
      options
    rescue OptionParser::InvalidOption => e
      raise ScriptOptionsError.new("Invalid option: #{e.message}")
    rescue OptionParser::MissingArgument => e
      raise ScriptOptionsError.new("Missing argument for option: #{e.message}")
    rescue OptionParser::InvalidArgument => e
      raise ScriptOptionsError.new("Invalid argument for option: #{e.message}")
    end

    private

    def set_dynamic_defaults
      default_model = Generators::AI_MODEL_DEFAULTS[options[:ai_service]]
      options[:ai_model] ||= default_model
    end

    def enforce_mandatory_options
      if options[:ai_service] != :fake
        missing = MANDATORY_OPTIONS.select { |param| options[param].nil? }
        raise OptionParser::MissingArgument, missing.join(', ') unless missing.empty?
      end
    end

    def define_options(parser)
      parser.banner = 'Usage: hyrum [options]'

      verbosity_options(parser)
      format_options(parser)
      message_options(parser)
      message_key_options(parser)
      number_options(parser)
      ai_service_options(parser)
      on_tail_options(parser)
    end

    def on_tail_options(parser)
      parser.on_tail('-h', '--help', 'Show this message') do
        puts parser
        exit
      end

      parser.on_tail('--version', 'Show version') do
        puts Hyrum::VERSION
        exit
      end
    end

    def ai_service_options(parser)
      options[:ai_service] = :fake

      description = "AI service: one of #{Generators::AI_SERVICES.join(', ')} (default: fake)"
      parser.on('-s SERVICE', '--service SERVICE', Generators::AI_SERVICES, description) do |service|
        options[:ai_service] = service.to_sym
      end

      description = 'AI model: must be a valid model for the selected service'
      parser.on('-d MODEL', '--model MODEL', description) do |model|
        options[:ai_model] = model.to_sym
      end
    end

    def message_key_options(parser)
      options[:key] = :status

      parser.on('-k KEY', '--key KEY', 'Message key (default: status)') do |key|
        options[:key] = key.to_sym
      end
    end

    def message_options(parser)
      parser.on('-m MESSAGE', '--message MESSAGE', 'Status message (required unless fake)') do |message|
        options[:message] = message
      end
    end

    def number_options(parser)
      options[:number] = 5

      parser.on('-n NUMBER', '--number NUMBER', Integer, 'Number of messages to generate (default: 5)',) do |number|
        options[:number] = number.to_i
      end
    end

    def verbosity_options(parser)
      parser.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
        options[:verbose] = v
      end
    end

    def format_options(parser)
      options[:format] = :text

      formats = Formats::FORMATS
      description = 'Output format. Supported formats are:'
      supported   = formats.join(', ')
      parser.on('-f FORMAT', '--format FORMAT', formats, description, supported, "(default: text)") do |format|
        options[:format] = format
      end
    end
  end
end
