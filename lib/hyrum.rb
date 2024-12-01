# frozen_string_literal: true

require 'optparse'
require 'zeitwerk'
loader = Zeitwerk::Loader.for_gem
loader.setup

module Hyrum
  def self.run(args)
    options = ScriptOptions.new(args).parse
    generator_opts = options.slice(:message, :key, :ai_service, :ai_model, :verbose)
    formatter_opts = options.slice(:format, :verbose)

    puts "Options: #{options.inspect}" if options[:verbose]
    formatter = Formats::Formatter.new(formatter_opts)
    message_generator = Generators::MessageGenerator.create(generator_opts)
    messages = message_generator.generate
    output = formatter.format(messages)
    puts output
  end
end

loader.eager_load
