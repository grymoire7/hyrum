# frozen_string_literal: true

module Hyrum
  module Generators
    class FakeGenerator
      FAKE_MESSAGES = %(
        {
          "e400": [
            "Bad Request: The server cannot process the request due to client error",
            "Invalid syntax in the request parameters",
            "The request could not be understood by the server",
            "Missing required parameters in the request",
            "Malformed request syntax"
          ],
          "e401": [
            "Unauthorized: Authentication is required to access this resource",
            "Invalid credentials provided",
            "Access token has expired",
            "Missing authentication token",
            "You must log in to access this resource"
          ],
          "e402": [
            "Payment Required: The requested resource requires payment",
            "Subscription has expired",
            "Please upgrade your account to access this feature",
            "Payment verification failed",
            "Resource access requires premium subscription"
          ],
          "e403": [
            "Forbidden: You don't have permission to access this resource",
            "Access denied due to insufficient privileges",
            "Your IP address has been blocked",
            "Account suspended",
            "Resource access restricted to authorized users only"
          ],
          "e404": [
            "Not Found: The requested resource could not be located",
            "The page you're looking for doesn't exist",
            "Resource has been moved or deleted",
            "Invalid URL or endpoint",
            "The requested item is no longer available"
          ],
          "e405": [
            "Method Not Allowed: The requested HTTP method is not supported",
            "This endpoint doesn't support the specified HTTP method",
            "Invalid HTTP method for this resource",
            "Please check the API documentation for supported methods",
            "HTTP method not supported for this endpoint"
          ],
          "e406": [
            "Not Acceptable: Cannot generate response matching Accept headers",
            "Requested format is not available",
            "Content type negotiation failed",
            "Server cannot generate acceptable response",
            "Unsupported media type requested"
          ],
          "e407": [
            "Proxy Authentication Required: Authentication with proxy server needed",
            "Please authenticate with the proxy first",
            "Proxy credentials required",
            "Missing proxy authentication",
            "Cannot proceed without proxy authentication"
          ],
          "e408": [
            "Request Timeout: The server timed out waiting for the request",
            "Client took too long to send the complete request",
            "Connection timed out while waiting for data",
            "Request processing exceeded time limit",
            "Please try submitting your request again"
          ],
          "e409": [
            "Conflict: Request conflicts with current state of the server",
            "Resource version conflict detected",
            "Concurrent modification error",
            "Data conflict with existing resource",
            "Cannot process due to resource state conflict"
          ],
          "e410": [
            "Gone: The requested resource is no longer available",
            "Resource has been permanently removed",
            "This version of the API has been deprecated",
            "Content has been permanently deleted",
            "Resource not available at this location"
          ],
          "e411": [
            "Length Required: Content-Length header is required",
            "Missing Content-Length header in request",
            "Request must include content length",
            "Cannot process request without content length",
            "Please specify the content length"
          ],
          "e412": [
            "Precondition Failed: Request preconditions failed",
            "Resource state doesn't match expectations",
            "Conditional request failed",
            "Required conditions not met",
            "Cannot proceed due to failed preconditions"
          ],
          "e413": [
            "Payload Too Large: Request entity exceeds limits",
            "File size is too large",
            "Request data exceeds maximum allowed size",
            "Please reduce the size of your request",
            "Upload size limit exceeded"
          ],
          "e414": [
            "URI Too Long: The requested URL exceeds server limits",
            "URL length exceeds maximum allowed characters",
            "Request URL is too long to process",
            "Please shorten the URL and try again",
            "URI length exceeds server configuration"
          ],
          "e415": [
            "Unsupported Media Type: Request format not supported",
            "Invalid content type in request",
            "Server doesn't support this media format",
            "Please check supported content types",
            "Media type not accepted by the server"
          ],
          "e416": [
            "Range Not Satisfiable: Cannot fulfill requested range",
            "Requested range not available",
            "Invalid range specified in request",
            "Range header value not satisfiable",
            "Cannot serve the requested content range"
          ],
          "e417": [
            "Expectation Failed: Server cannot meet Expect header requirements",
            "Expected condition could not be fulfilled",
            "Server cannot satisfy expectations",
            "Expect header requirements not met",
            "Request expectations cannot be met"
          ],
          "e418": [
            "I'm a teapot: Server refuses to brew coffee with a teapot",
            "This server is a teapot, not a coffee maker",
            "Coffee brewing request denied by teapot",
            "Hyper Text Coffee Pot Control Protocol error",
            "Cannot brew coffee using teapot protocol"
          ],
          "e421": [
            "Misdirected Request: Server is not able to produce a response",
            "Request was directed to wrong server",
            "Cannot handle misdirected request",
            "Invalid server configuration for request",
            "Request cannot be processed by this server"
          ],
          "e422": [
            "Unprocessable Entity: Request semantically incorrect",
            "Validation failed for the request",
            "Cannot process invalid request data",
            "Semantic errors in request content",
            "Request contains invalid parameters"
          ],
          "e423": [
            "Locked: Resource is locked",
            "Resource access blocked by lock",
            "Cannot modify locked resource",
            "Resource temporarily unavailable due to lock",
            "Please wait for resource lock to clear"
          ],
          "e424": [
            "Failed Dependency: Request failed due to previous request failure",
            "Dependent request failed",
            "Cannot proceed due to failed dependency",
            "Previous request failure prevents completion",
            "Dependency chain broken"
          ],
          "e425": [
            "Too Early: Server unwilling to risk processing early request",
            "Request arrived too early to process",
            "Cannot handle premature request",
            "Please retry request later",
            "Early request rejected"
          ],
          "e426": [
            "Upgrade Required: Client must upgrade protocol",
            "Please upgrade to continue",
            "Protocol upgrade necessary",
            "Current protocol version not supported",
            "Connection upgrade required"
          ],
          "e428": [
            "Precondition Required: Request must be conditional",
            "Missing required precondition",
            "Please include precondition headers",
            "Cannot process request without preconditions",
            "Conditional request required"
          ],
          "e429": [
            "Too Many Requests: Rate limit exceeded",
            "Please slow down your requests",
            "API rate limit reached",
            "Too many requests in time window",
            "Request quota exceeded"
          ],
          "e431": [
            "Request Header Fields Too Large: Header fields too large",
            "Headers exceed size limits",
            "Request contains oversized headers",
            "Please reduce header size",
            "Header fields exceed server limits"
          ],
          "e451": [
            "Unavailable For Legal Reasons: Content legally restricted",
            "Access denied due to legal restrictions",
            "Content blocked for legal reasons",
            "Resource legally unavailable",
            "Cannot serve content due to legal constraints"
          ],
          "e500": [
            "Internal Server Error: Something went wrong on our end",
            "Unexpected server error occurred",
            "Server encountered an error processing request",
            "Internal error in server configuration",
            "System error, please try again later"
          ],
          "e501": [
            "Not Implemented: Functionality not supported",
            "Request method not supported by server",
            "Feature not available on this server",
            "Requested functionality not implemented",
            "Server does not support this operation"
          ],
          "e502": [
            "Bad Gateway: Invalid response from upstream server",
            "Gateway received invalid response",
            "Error communicating with upstream server",
            "Invalid response from backend service",
            "Gateway communication error"
          ],
          "e503": [
            "Service Unavailable: Server temporarily unavailable",
            "System under maintenance",
            "Server is overloaded",
            "Service temporarily offline",
            "Please try again later"
          ],
          "e504": [
            "Gateway Timeout: Upstream server timed out",
            "Gateway connection timed out",
            "Backend server not responding",
            "Request timed out at gateway",
            "Gateway failed to get timely response"
          ],
          "e505": [
            "HTTP Version Not Supported: HTTP version not supported",
            "Unsupported HTTP protocol version",
            "Server doesn't support HTTP version",
            "Please use a supported HTTP version",
            "HTTP protocol version not compatible"
          ],
          "e506": [
            "Variant Also Negotiates: Server configuration error",
            "Circular reference in content negotiation",
            "Internal configuration conflict",
            "Content negotiation error",
            "Server misconfiguration detected"
          ],
          "e507": [
            "Insufficient Storage: Server out of storage",
            "Not enough storage space available",
            "Storage quota exceeded",
            "Server storage capacity reached",
            "Cannot process due to storage limits"
          ],
          "e508": [
            "Loop Detected: Infinite loop detected in request",
            "Request processing loop detected",
            "Circular dependency found",
            "Cannot complete due to infinite loop",
            "Processing halted due to loop"
          ],
          "e510": [
            "Not Extended: Further extensions needed",
            "Required extension not supported",
            "Cannot fulfill without extension",
            "Missing required protocol extension",
            "Extension support required"
          ],
          "e511": [
            "Network Authentication Required: Network access requires authentication",
            "Please authenticate with network",
            "Network login required",
            "Cannot access network without authentication",
            "Network credentials required"
          ]
        }
      )

      attr_reader :options

      def initialize(options)
        @options = options
        # @ai_service = options[:ai_service]
      end

      def generate
        messages = JSON.parse(FAKE_MESSAGES)
        key = options[:key]&.downcase
        number = (options[:number] || 1).to_i

        return messages unless key

        key_with_prefix = key.start_with?('e') ? key : "e#{key}"
        available_messages = messages[key_with_prefix] || []
        available_messages.sample([number, available_messages.length].min)
      end
    end
  end
end
