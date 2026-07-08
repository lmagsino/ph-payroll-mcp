# frozen_string_literal: true

require_relative "base_calculator"

module Payroll
  # SSS contribution. Not a linear rate — a stepped Monthly Salary Credit (MSC)
  # schedule, plus the WISP/MPF provident-fund layer on the MSC portion above the
  # WISP threshold (eng-review D9), plus an employer-only EC contribution.
  #
  #   msc          = salary rounded to its MSC bracket, clamped to floor..ceiling
  #   regular_msc  = min(msc, wisp_threshold)      # regular SS program
  #   wisp_msc     = max(0, msc - wisp_threshold)  # mandatory provident fund
  #   employed     → ER/EE split on each portion; EC (employer) flat by MSC band
  #   self/vol/ofw → member pays the full total rate; no employer share, no EC
  #
  # NOTE: MSC bracketing here rounds to msc_step; the real SSS table has a few
  # irregular ranges at the extremes. CONFIRM the schedule, the 2026 rate, the WISP
  # mechanics, and the EC threshold against the SSS circular; expected test values
  # will move with the verified numbers.
  class SssCalculator < BaseCalculator
    agency "sss"

    MEMBER_TYPES = %w[employed self_employed voluntary ofw].freeze

    private

    def validate!(monthly_salary:, member_type:)
      validate_positive_finite!(monthly_salary, field: "monthly_salary")
      return if MEMBER_TYPES.include?(member_type.to_s)

      raise InvalidInput, "member_type must be one of #{MEMBER_TYPES.join(', ')}"
    end

    def compute(table, monthly_salary:, member_type:)
      floor = member_type.to_s == "ofw" ? table.decimal("ofw_msc_floor") : table.decimal("msc_floor")
      msc = msc_for(monthly_salary, floor: floor, ceiling: table.decimal("msc_ceiling"), step: table.decimal("msc_step"))

      wisp_threshold = table.decimal("wisp_threshold")
      regular_msc = [msc, wisp_threshold].min
      wisp_msc = [msc - wisp_threshold, BigDecimal(0)].max

      if member_type.to_s == "employed"
        ee = table.decimal("rate_employee")
        er = table.decimal("rate_employer")
        reg_ee = round_centavo(regular_msc * ee)
        reg_er = round_centavo(regular_msc * er)
        wisp_ee = round_centavo(wisp_msc * ee)
        wisp_er = round_centavo(wisp_msc * er)
        ec = msc >= table.decimal("ec_threshold") ? table.decimal("ec_high") : table.decimal("ec_low")
      else
        # Self-employed / voluntary / OFW pay the full total rate themselves.
        total = table.decimal("rate_total")
        reg_ee = round_centavo(regular_msc * total)
        wisp_ee = round_centavo(wisp_msc * total)
        reg_er = wisp_er = ec = BigDecimal(0)
      end

      employee_share = reg_ee + wisp_ee
      employer_share = reg_er + wisp_er + ec

      {
        msc: msc,
        regular_employee: reg_ee, regular_employer: reg_er,
        wisp_employee: wisp_ee, wisp_employer: wisp_er,
        ec_contribution: ec,
        employee_share: employee_share, employer_share: employer_share,
        total: employee_share + employer_share
      }
    end

    # Round salary to its MSC bracket (nearest msc_step), clamped to floor..ceiling.
    def msc_for(salary, floor:, ceiling:, step:)
      s = bd(salary)
      return floor if s <= floor
      return ceiling if s >= ceiling

      bracket = ((s + step / 2) / step).floor * step
      clamp(bracket, floor: floor, ceiling: ceiling)
    end
  end
end
