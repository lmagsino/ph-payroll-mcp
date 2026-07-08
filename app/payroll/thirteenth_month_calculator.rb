# frozen_string_literal: true

require_relative "base_calculator"

module Payroll
  # 13th-month pay: total basic salary earned in the year / 12, with the portion up
  # to the tax-exempt threshold exempt and the excess taxable.
  #
  #   thirteenth = total_basic / 12
  #   exempt     = min(thirteenth, threshold)   # threshold ~ ₱90,000 (CONFIRM)
  #   taxable    = thirteenth - exempt
  #
  # months_worked is validated (1..12) but proration is inherent to total_basic
  # (it already reflects months actually worked). CONFIRM the threshold and the
  # intended proration semantics against BIR guidance.
  class ThirteenthMonthCalculator < BaseCalculator
    agency "thirteenth_month"

    private

    def validate!(total_basic_salary_earned_this_year:, months_worked:)
      validate_positive_finite!(total_basic_salary_earned_this_year, field: "total_basic_salary_earned_this_year")
      return if months_worked.is_a?(Integer) && months_worked.between?(1, 12)

      raise InvalidInput, "months_worked must be an integer between 1 and 12"
    end

    def compute(table, total_basic_salary_earned_this_year:, months_worked:)
      thirteenth = round_centavo(bd(total_basic_salary_earned_this_year) / 12)
      threshold = table.decimal("exempt_threshold")
      exempt = [thirteenth, threshold].min
      taxable = thirteenth - exempt

      { thirteenth_month_pay: thirteenth, tax_exempt_portion: exempt, taxable_portion: taxable }
    end
  end
end
