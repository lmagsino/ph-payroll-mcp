# frozen_string_literal: true

require_relative "base_tool"

module Tools
  class ComputeSssContribution < BaseTool
    tool_name "compute_sss_contribution"
    description "Compute the current SSS contribution (employee, employer, EC, and WISP " \
                "portions) for a Philippine monthly salary and member type. Returns the " \
                "amounts with the effective date and source circular."

    input_schema(
      properties: {
        monthly_salary: MONEY.merge(description: "Monthly salary in PHP"),
        member_type: { type: "string", enum: PhPayroll::SssCalculator::MEMBER_TYPES, description: "SSS member type" }
      },
      required: %w[monthly_salary member_type],
      additionalProperties: false
    )

    class << self
      def call(monthly_salary:, member_type:)
        domain { PhPayroll::SssCalculator.new.call(monthly_salary: monthly_salary, member_type: member_type).to_h }
      end
    end
  end
end
