# frozen_string_literal: true

require_relative "base_tool"

module Tools
  class ComputeNetPay < BaseTool
    tool_name "compute_net_pay"
    description "Compute a full Philippine monthly payslip from gross to net: SSS, " \
                "PhilHealth, Pag-IBIG employee shares, withholding tax on taxable income, " \
                "optional other deductions, and net pay. Every deduction is cited to its " \
                "source circular under `sources`."

    arguments do
      required(:gross_monthly_salary).filled.description("Gross monthly salary in PHP (number)")
      required(:member_type).filled(:string)
        .description("SSS member type: employed, self_employed, voluntary, ofw")
      optional(:other_deductions).filled.description("Other monthly deductions in PHP (number), default 0")
    end

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
