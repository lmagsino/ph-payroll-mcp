# frozen_string_literal: true

require "date"
require_relative "base_tool"

module Tools
  class GetContributionTable < BaseTool
    tool_name "get_contribution_table"
    description "Return a raw Philippine payroll reference table (sss, philhealth, pagibig, " \
                "withholding_tax, thirteenth_month, premium_pay, holidays), with its effective " \
                "date and source circular — so the actual rule can be cited instead of trusting " \
                "a computed number."

    input_schema(
      properties: {
        table: { type: "string", enum: PhPayroll::TableSchema::KNOWN_AGENCIES },
        as_of: { type: "string", format: "date", description: "ISO date (YYYY-MM-DD); defaults to today" }
      },
      required: %w[table],
      additionalProperties: false
    )

    class << self
      def call(table:, as_of: nil)
        domain do
          entry = PhPayroll::RateTables.for(table, as_of: as_of || Date.today)
          {
            agency: entry.agency,
            effective_date: entry.effective_date,
            source_circular: entry.source_circular,
            data: entry.data
          }
        end
      end
    end
  end
end
