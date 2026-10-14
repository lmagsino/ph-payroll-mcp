# frozen_string_literal: true

require_relative "base_tool"

module Tools
  class ComputePhilhealthContribution < BaseTool
    tool_name "compute_philhealth_contribution"
    description "Compute the current PhilHealth monthly premium (employee and employer " \
                "share) for a Philippine monthly salary. Returns the amounts with the " \
                "effective date and source circular so the figure is auditable."

    input_schema(
      properties: { monthly_salary: MONEY.merge(description: "Monthly basic salary in PHP") },
      required: %w[monthly_salary],
      additionalProperties: false
    )

    class << self
      def call(monthly_salary:)
        domain { PhPayroll::PhilhealthCalculator.new.call(monthly_salary: monthly_salary).to_h }
      end
    end
  end
end
