# frozen_string_literal: true

require "date"
require_relative "base_tool"

module Tools
  class GetContributionTable < BaseTool
    tool_name "get_contribution_table"
    description "Return the raw Philippine contribution/tax reference table for an agency " \
                "(sss, philhealth, pagibig, withholding_tax, thirteenth_month), with its " \
                "effective date and source circular — so the actual rule can be cited " \
                "instead of trusting a computed number."

    arguments do
      required(:table).filled(:string)
        .description("One of: sss, philhealth, pagibig, withholding_tax, thirteenth_month")
      optional(:as_of).filled(:string).description("ISO date (YYYY-MM-DD); defaults to today")
    end

    def call(table:, as_of: nil)
      domain do
        entry = Payroll::RateTables.for(table, as_of: as_of || Date.today)
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
