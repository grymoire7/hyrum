# frozen_string_literal: true

module Hyrum
  module Generators
    class FakeGenerator
      DATA_FILE = File.expand_path('../data/fake_messages.json', __dir__)

      attr_reader :options

      def initialize(options)
        @options = options
      end

      def generate
        messages = load_messages
        key = options[:key]&.downcase
        number = (options[:number] || 1).to_i

        return messages unless key

        key_with_prefix = key.start_with?('e') ? key : "e#{key}"
        available_messages = messages[key_with_prefix] || []
        selected_messages = available_messages.sample([number, available_messages.length].min)

        # Return as a hash to match expected format
        { options[:key] => selected_messages }
      end

      private

      def load_messages
        JSON.parse(File.read(DATA_FILE))
      end
    end
  end
end
