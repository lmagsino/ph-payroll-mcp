# frozen_string_literal: true

require_relative "base_tool"

module Tools
  class ComputeNetPay < BaseTool
    tool_name "compute_net_pay"
    description "Compute a full Philippine monthly payslip from gross to net: SSS, " \
                "PhilHealth, Pag-IBIG employee shares, withholding tax on taxable income, " \
                "optional other deductions, and net pay. Every deduction is cited to its " \
                "source circular under `sources`."

    input_schema(
      properties: {
        gross_monthly_salary: MONEY.merge(description: "Gross monthly salary in PHP"),
        member_type: { type: "string", enum: Payroll::SssCalculator::MEMBER_TYPES, description: "SSS member type" },
        other_deductions: MONEY.merge(default: 0, description: "Other monthly deductions in PHP")
      },
      required: %w[gross_monthly_salary member_type],
      additionalProperties: false
    )

    class << self
      def call(gross_monthly_salary:, member_type:, other_deductions: 0)
        domain do
          Payroll::NetPayCalculator.new.call(
            gross_monthly_salary: gross_monthly_salary,
            member_type: member_type,
            other_deductions: other_deductions
          )
        end
      end
    end
  end
end
