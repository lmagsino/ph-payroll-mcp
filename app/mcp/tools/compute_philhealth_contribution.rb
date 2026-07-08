# frozen_string_literal: true

require_relative "base_tool"

module Tools
  class ComputePhilhealthContribution < BaseTool
    tool_name "compute_philhealth_contribution"
    description "Compute the current PhilHealth monthly premium (employee and employer " \
                "share) for a Philippine monthly salary. Returns the amounts with the " \
                "effective date and source circular so the figure is auditable."

    arguments do
      # Untyped `filled` accepts both JSON integers and floats (LLMs send either); the
      # domain layer coerces to BigDecimal and rejects non-numeric/negative input.
      required(:monthly_salary).filled.description("Monthly basic salary in PHP (number)")
    end

    def call(monthly_salary:)
      domain { Payroll::PhilhealthCalculator.new.call(monthly_salary: monthly_salary).to_h }
    end
  end
end
