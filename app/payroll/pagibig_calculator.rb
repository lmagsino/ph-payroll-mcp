# frozen_string_literal: true

require_relative "base_calculator"

module Payroll
  # Pag-IBIG (HDMF) contribution. Employee rate depends on a monthly-comp threshold;
  # the employer rate is flat. The contribution base is capped at the monthly ceiling
  # (so contributions max out at ceiling * rate).
  #
  #   base   = min(salary, ceiling)
  #   ee_rate = salary <= low_threshold ? low_rate_ee : rate_ee
  #   employee = base * ee_rate ;  employer = base * rate_er
  #
  # Circular 460 keys the 1% rate on the fund salary ("₱1,500 and below"). Keying on
  # the actual salary is equivalent only while the ceiling stays above low_threshold.
  class PagibigCalculator < BaseCalculator
    agency "pagibig"

    private

    def validate!(monthly_salary:)
      validate_positive_finite!(monthly_salary, field: "monthly_salary")
    end

    def compute(table, monthly_salary:)
      salary = bd(monthly_salary)
      base = clamp(salary, floor: 0, ceiling: table.decimal("ceiling"))

      ee_rate = salary <= table.decimal("low_threshold") ? table.decimal("low_rate_ee") : table.decimal("rate_ee")
      employee_share = round_centavo(base * ee_rate)
      employer_share = round_centavo(base * table.decimal("rate_er"))

      { employee_share: employee_share, employer_share: employer_share, total: employee_share + employer_share }
    end
  end
end
