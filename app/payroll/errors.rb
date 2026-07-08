# frozen_string_literal: true

module Payroll
  # Base for every domain error. All raise-with-a-clear-message errors in the
  # payroll layer inherit this so callers (and the MCP adapters) can rescue one type.
  class Error < StandardError; end

  # Raised when input is semantically invalid (negative/non-finite salary, bad enum,
  # unparseable number). Distinct from a schema/type error caught earlier by fast-mcp.
  class InvalidInput < Error; end
end
