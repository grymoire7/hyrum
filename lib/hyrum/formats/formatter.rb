# frozen_string_literal: true

require 'erb'

module Hyrum
  module Formats
    FORMATS = %i[ruby javascript python java text json].freeze

    class Formatter
      attr_reader :options

      def initialize(options)
        @options = options
      end

      def format(messages, validation_result = nil)
        template_file = File.join(__dir__, 'templates', "#{options[:format]}.erb")
        template = ERB.new(File.read(template_file), trim_mode: '-')
        template.result_with_hash(
          messages: messages,
          validation_result: validation_result,
          show_scores: options[:show_scores]
        )
      end
    end
  end
end
