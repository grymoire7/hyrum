# frozen_string_literal: true

require 'optparse'

module Hyrum
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
      options
    rescue OptionParser::InvalidOption => e
      err = "Invalid option: #{e.message}"
    rescue OptionParser::MissingArgument => e
      err = "Missing argument for option: #{e.message}"
    rescue OptionParser::InvalidArgument => e
      err = "Invalid argument for option: #{e.message}"
    ensure
      if err
        puts err
        exit
      end
    end

    private

    def enforce_mandatory_options
      missing = MANDATORY_OPTIONS.select { |param| options[param].nil? }
      return if missing.empty?

      raise OptionParser::MissingArgument, missing.join(', ')
    end

    def define_options(parser)
      parser.banner = 'Usage: hyrum [options]'

      verbosity_options(parser)
      format_options(parser)
      message_options(parser)
      message_key_options(parser)
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
      description = "AI service: one of #{Generators::AI_SERVICES.join(', ')}"
      parser.on('-s SERVICE', '--service SERVICE', Generators::AI_SERVICES, description) do |service|
        options[:ai_service] = service.to_sym
      end
      options[:ai_service] ||= :fake

      default_model = Generators::AI_MODEL_DEFAULTS[options[:ai_service]]
      description = 'AI model: must be a valid model for the selected service'
      parser.on('-d MODEL', '--model MODEL', description) do |model|
        options[:ai_model] = model.to_sym
      end
      options[:ai_model] ||= default_model
    end

    def message_key_options(parser)
      parser.on('-k KEY', '--key KEY', 'Message key') do |key|
        options[:key] = key
      end
      options[:key] ||= 'status'
    end

    def message_options(parser)
      parser.on('-m MESSAGE', '--message MESSAGE', 'Status message') do |message|
        options[:message] = message
      end
    end

    def verbosity_options(parser)
      parser.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
        options[:verbose] = v
      end
    end

    def format_options(parser)
      formats = Formats::FORMATS
      description = 'Output format. Supported formats are:'
      supported   = formats.join(', ')
      parser.on('-f FORMAT', '--format FORMAT', formats, description, supported) do |format|
        options[:format] = format
      end
      options[:format] ||= :text
    end
  end
end
