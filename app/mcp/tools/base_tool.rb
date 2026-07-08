# frozen_string_literal: true

require "json"
require "bigdecimal"
require "date"
require "fast_mcp"

module Tools
  # Base for every MCP tool adapter. Adapters stay thin: parse args, call a domain
  # object, return its hash. This base handles the two cross-cutting concerns so no
  # adapter repeats them:
  #
  #   1. Result formatting — fast-mcp serializes a plain hash with `.to_s` (ugly Ruby
  #      inspect). We wrap payloads as an MCP text-content block of clean JSON, and
  #      deep-coerce BigDecimal -> 2dp float and Date -> ISO string so nothing leaks.
  #   2. Error mapping — domain errors become a structured tool payload the LLM relays,
  #      instead of an unhandled raise (which fast-mcp would dump as a stack trace).
  class BaseTool < FastMcp::Tool
    private

    # Run a domain call and return an MCP content block; translate Payroll errors.
    def domain
      respond(yield)
    rescue Payroll::InvalidInput => e
      respond(error: "invalid_input", message: e.message)
    rescue Payroll::RateTables::MissingRateTable => e
      respond(error: "no_rate_table", message: e.message)
    end

    def respond(payload)
      { content: [{ type: "text", text: JSON.generate(jsonify(payload)) }] }
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
