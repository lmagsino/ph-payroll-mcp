# frozen_string_literal: true

require_relative "base_tool"

module Tools
  class Compute13thMonthPay < BaseTool
    tool_name "compute_13th_month_pay"
    description "Compute 13th-month pay and its tax-exempt / taxable split for a Philippine " \
                "employee, from total basic salary earned this year. Returns the amounts with " \
                "the effective date and source reference."

    input_schema(
      properties: {
        total_basic_salary_earned_this_year: MONEY.merge(description: "Total basic salary earned in the year, in PHP"),
        months_worked: { type: "integer", description: "Whole months worked this year, 1-12" }
      },
      required: %w[total_basic_salary_earned_this_year months_worked],
      additionalProperties: false
    )

    class << self
      def call(total_basic_salary_earned_this_year:, months_worked:)
        domain do
          PhPayroll::ThirteenthMonthCalculator.new.call(
            total_basic_salary_earned_this_year: total_basic_salary_earned_this_year,
            months_worked: months_worked
          ).to_h
        end
      end
    end
  end
end
