# frozen_string_literal: true

require "json"
require "bigdecimal"
require "date"
require "mcp"

module Tools
  # Base for every MCP tool adapter. Adapters stay thin: declare a JSON Schema, call a
  # domain object, return its hash. This base handles the two cross-cutting concerns so
  # no adapter repeats them:
  #
  #   1. Result formatting — payloads become one MCP text-content block of clean JSON,
  #      deep-coercing BigDecimal -> 2dp float and Date -> ISO string so nothing leaks.
  #   2. Error mapping — domain errors become a structured `{error, message}` payload
  #      flagged isError, which the LLM can relay. Anything else raised reaches the SDK,
  #      which answers with a generic internal error and never echoes the message.
  class BaseTool < MCP::Tool
    MONEY = { type: "number" }.freeze

    class << self
      private

      # Run a domain call and return a tool response; translate Payroll errors.
      def domain
        respond(yield)
      rescue Payroll::InvalidInput => e
        respond({ error: "invalid_input", message: e.message }, error: true)
      rescue Payroll::RateTables::MissingRateTable => e
        respond({ error: "no_rate_table", message: e.message }, error: true)
      end

      def respond(payload, error: false)
        MCP::Tool::Response.new([{ type: "text", text: JSON.generate(jsonify(payload)) }], error: error)
      end

      def jsonify(obj)
        case obj
        when BigDecimal then obj.round(2, BigDecimal::ROUND_HALF_UP).to_f
        when Date then obj.iso8601
        when Hash then obj.transform_values { |v| jsonify(v) }
        when Array then obj.map { |v| jsonify(v) }
        else obj
        end
      end
    end
  end
end
