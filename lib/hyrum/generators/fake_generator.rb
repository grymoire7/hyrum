# frozen_string_literal: true

module Hyrum
  module Generators
    class FakeGenerator
      FAKE_MESSAGES = %(
        {
          "e404": [
            "We couldn't locate the resource you were looking for.",
            "The resource you requested is not available at this time.",
            "Unfortunately, we were unable to find the specified resource.",
            "It seems the resource you're searching for does not exist.",
            "The item you are trying to access is currently missing."
          ],
          "e418": [
            "I'm a teapot",
            "The server refuses the attempt to brew coffee with a teapot",
            "Coffee brewing denied: a teapot is not suitable for this operation.",
            "Request failed: the server cannot process coffee with a teapot.",
            "Brewing error: teapots are incompatible with coffee preparation.",
            "Action halted: using a teapot to brew coffee is not permitted.",
            "Invalid request: please use a coffee maker instead of a teapot."
          ],
          "e500": [
            "Internal Server Error",
            "An unexpected condition was encountered"
          ],
          "e503": [
            "Service Unavailable",
            "The server is currently unavailable"
          ],
          "e504": [
            "Gateway Timeout",
            "The server is currently unavailable"
          ]
        }
      )

      attr_reader :options

      def initialize(options)
        @options = options
        @ai_service = options[:ai_service]
      end

      def generate
        JSON.parse(FAKE_MESSAGES)
      end
    end
  end
end
