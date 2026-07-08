# frozen_string_literal: true

require_relative "base_tool"

module Tools
  class ComputeWithholdingTax < BaseTool
    tool_name "compute_withholding_tax"
    description "Compute BIR monthly withholding tax on a Philippine monthly taxable " \
                "income using the period-based Revised Withholding Tax table. Returns the " \
                "tax, the bracket, the effective date, and the source circular."

    arguments do
      required(:monthly_taxable_income).filled.description("Monthly taxable income in PHP (number)")
      optional(:pay_period).filled(:string).description("Pay period; only 'monthly' is supported in v1")
    end

    def call(monthly_taxable_income:, pay_period: "monthly")
      domain do
        Payroll::WithholdingTaxCalculator.new
                                         .call(monthly_taxable_income: monthly_taxable_income, pay_period: pay_period)
                                         .to_h
      end
    end
  end
end
