# frozen_string_literal: true

require "optparse"

module Hyrum
  class ScriptOptionsError < StandardError; end

  class ScriptOptions
    MANDATORY_OPTIONS = %i[message].freeze

    attr_reader :options

    def initialize(args)
      @options = {
        message: nil,
        validate: false,
        min_quality: 70,
        strict: false,
        show_scores: false,
        model_strategy: :stable
      }
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
      raise ScriptOptionsError, "Invalid option: #{e.message}"
    rescue OptionParser::MissingArgument => e
      raise ScriptOptionsError, "Missing argument for option: #{e.message}"
    rescue OptionParser::InvalidArgument => e
      raise ScriptOptionsError, "Invalid argument for option: #{e.message}"
    end

    private

    def set_dynamic_defaults
      return if options[:ai_model]

      service = options[:ai_service]
      strategy = options[:model_strategy]

      if (family = Generators::AI_MODEL_FAMILIES[service])
        options[:ai_model] = ModelResolver.resolve(
          provider: service,
          family: family,
          strategy: strategy
        )
      elsif (literal = Generators::AI_MODEL_LITERALS[service])
        options[:ai_model] = literal
      end
    rescue ModelResolver::ModelNotFoundError => e
      raise ScriptOptionsError, "Model resolution failed: #{e.message}"
    end

    def enforce_mandatory_options
      return unless options[:ai_service] != :fake

      missing = MANDATORY_OPTIONS.select { |param| options[param].nil? }
      raise OptionParser::MissingArgument, missing.join(", ") unless missing.empty?
    end

    def define_options(parser)
      parser.banner = "Usage: hyrum [options]"

      verbosity_options(parser)
      format_options(parser)
      message_options(parser)
      message_key_options(parser)
      number_options(parser)
      ai_service_options(parser)
      validation_options(parser)
      on_tail_options(parser)
    end

    def on_tail_options(parser)
      parser.on_tail("-h", "--help", "Show this message") do
        puts parser
        exit
      end

      parser.on_tail("--version", "Show version") do
        puts Hyrum::VERSION
        exit
      end
    end

    def ai_service_options(parser)
      options[:ai_service] = :fake

      description = "AI service: one of #{Generators::AI_SERVICES.join(", ")} (default: fake)"
      parser.on("-s SERVICE", "--service SERVICE", Generators::AI_SERVICES, description) do |service|
        options[:ai_service] = service.to_sym
      end

      description = "AI model: must be a valid model for the selected service"
      parser.on("-d MODEL", "--model MODEL", description) do |model|
        options[:ai_model] = model.to_sym
      end

      strategies = %w[cheapest newest stable]
      description = "Model selection strategy: #{strategies.join(", ")} (default: cheapest)"
      parser.on("--model-strategy STRATEGY", strategies, description) do |strategy|
        options[:model_strategy] = strategy.to_sym
      end
    end

    def message_key_options(parser)
      parser.on("-k KEY", "--key KEY", "Message key (default: status)") do |key|
        options[:key] = key.to_sym
      end
    end

    def message_options(parser)
      parser.on("-m MESSAGE", "--message MESSAGE", "Status message (required unless fake)") do |message|
        options[:message] = message
      end
    end

    def number_options(parser)
      parser.on("-n NUMBER", "--number NUMBER", Integer, "Number of messages to generate (default: 5)") do |number|
        options[:number] = number.to_i
      end
    end

    def verbosity_options(parser)
      parser.on("-v", "--[no-]verbose", "Run verbosely") do |v|
        options[:verbose] = v
      end
    end

    def format_options(parser)
      formats = Formats::FORMATS
      description = "Output format. Supported formats are:"
      supported = formats.join(", ")
      parser.on("-f FORMAT", "--format FORMAT", formats, description, supported, "(default: text)") do |format|
        options[:format] = format
      end
    end

    def validation_options(parser)
      parser.on("--validate", "Enable quality validation (default: off)") do
        options[:validate] = true
      end

      parser.on("--min-quality SCORE", Integer, "Minimum quality score 0-100 (default: 70)") do |score|
        options[:min_quality] = score
      end

      parser.on("--strict", "Fail on quality issues instead of warning (default: false)") do
        options[:strict] = true
      end

      parser.on("--show-scores", "Include quality metrics in output (default: false)") do
        options[:show_scores] = true
      end
    end
  end
end
