# frozen_string_literal: true

require "bigdecimal"
require "date"
require_relative "errors"
require_relative "sss_calculator"
require_relative "philhealth_calculator"
require_relative "pagibig_calculator"
require_relative "withholding_tax_calculator"

module Payroll
  # Composite: a full monthly payslip, gross to net. Calls the four component
  # calculators directly (eng-review D1) and derives the withholding correctly —
  # the one real piece of composite math: mandatory contributions are pre-tax, so
  # taxable income = gross - (SSS + PhilHealth + Pag-IBIG employee shares).
  #
  #   taxable = gross - contribs
  #   net     = gross - contribs - withholding - other_deductions
  #
  # Unlike a single-agency calculator this draws on FOUR tables, so it does not
  # collapse into one Result — it returns per-source citations so every deduction
  # remains auditable to its circular.
  class NetPayCalculator
    def call(gross_monthly_salary:, member_type:, other_deductions: 0, as_of: Date.today)
      other = coerce_nonneg(other_deductions, field: "other_deductions")

      # SSS validates gross_monthly_salary (> 0) and member_type; let it raise.
      sss = SssCalculator.new.call(monthly_salary: gross_monthly_salary, member_type: member_type, as_of: as_of)
      phic = PhilhealthCalculator.new.call(monthly_salary: gross_monthly_salary, as_of: as_of)
      hdmf = PagibigCalculator.new.call(monthly_salary: gross_monthly_salary, as_of: as_of)

      gross = BigDecimal(gross_monthly_salary.to_s)
      sss_ee = sss.amounts[:employee_share]
      phic_ee = phic.amounts[:employee_share]
      hdmf_ee = hdmf.amounts[:employee_share]
      contribs = sss_ee + phic_ee + hdmf_ee

      taxable = [gross - contribs, BigDecimal(0)].max
      wtax_result = WithholdingTaxCalculator.new.call(monthly_taxable_income: taxable, as_of: as_of)
      wtax = wtax_result.amounts[:withholding_tax]

      total_deductions = contribs + wtax + other
      net_pay = gross - total_deductions # may be negative with large other_deductions — reported honestly

      {
        gross: gross,
        sss_employee: sss_ee,
        philhealth_employee: phic_ee,
        pagibig_employee: hdmf_ee,
        taxable_income: taxable,
        withholding_tax: wtax,
        other_deductions: other,
        total_deductions: total_deductions,
        net_pay: net_pay,
        sources: {
          sss: citation(sss),
          philhealth: citation(phic),
          pagibig: citation(hdmf),
          withholding_tax: citation(wtax_result)
        }
      }
    end

    private

    def citation(result)
      { effective_date: result.effective_date, source_circular: result.source_circular }
    end

    def coerce_nonneg(value, field:)
      decimal = BigDecimal(value.to_s)
      raise InvalidInput, "#{field} must not be negative" if decimal.negative?

      decimal
    rescue ArgumentError
      raise InvalidInput, "#{field} is not a valid number"
    end
  end
end
