# frozen_string_literal: true

require_relative "base_tool"

module Tools
  class ComputeSssContribution < BaseTool
    tool_name "compute_sss_contribution"
    description "Compute the current SSS contribution (employee, employer, EC, and WISP " \
                "portions) for a Philippine monthly salary and member type. Returns the " \
                "amounts with the effective date and source circular."

    arguments do
      required(:monthly_salary).filled.description("Monthly salary in PHP (number)")
      required(:member_type).filled(:string)
        .description("One of: employed, self_employed, voluntary, ofw")
    end

    def call(monthly_salary:, member_type:)
      domain { Payroll::SssCalculator.new.call(monthly_salary: monthly_salary, member_type: member_type).to_h }
    end
  end
end
