# frozen_string_literal: true

require_relative "base_calculator"

module Payroll
  # PhilHealth premium: a flat rate of monthly basic income within a floor/ceiling,
  # split 50/50 between employee and employer.
  #
  #   premium = clamp(salary, floor..ceiling) * rate
  #   employer = round(premium / 2) ;  employee = premium - employer
  #
  # The rounded half goes to the employer and the employee takes the remainder, so
  # EE + ER always reconciles exactly to premium.
  class PhilhealthCalculator < BaseCalculator
    agency "philhealth"

    private

    def validate!(monthly_salary:)
      validate_positive_finite!(monthly_salary, field: "monthly_salary")
    end

    def compute(table, monthly_salary:)
      base = clamp(monthly_salary, floor: table.decimal("floor"), ceiling: table.decimal("ceiling"))
      premium = round_centavo(base * table.decimal("rate"))

      # Split 50/50; the employer absorbs any odd centavo (rounded half) and the
      # employee takes the remainder, so EE + ER == premium. (v1 convention —
      # confirm against PhilHealth guidance.)
      employer_share = round_centavo(premium / 2)
      employee_share = premium - employer_share

      { premium: premium, employee_share: employee_share, employer_share: employer_share }
    end
  end
end
