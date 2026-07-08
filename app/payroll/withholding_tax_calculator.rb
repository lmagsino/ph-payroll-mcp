# frozen_string_literal: true

require_relative "base_calculator"

module Payroll
  # BIR withholding tax using the period-based Revised Withholding Tax Table
  # (eng-review D8) — NOT the annual TRAIN brackets. v1 supports the monthly column.
  #
  #   tax = base + rate * (income - bracket_floor)
  #
  # Brackets are the monthly RWT rows { over, base, rate }; the selected row is the
  # one with the greatest `over` not exceeding the income. The table is continuous
  # (each row's base equals the previous row evaluated at its start), so a value
  # exactly on a boundary yields the same tax under either adjacent row.
  #
  # CONFIRM the monthly RWT rows against the current BIR table before production
  # (the values here are the widely-published TRAIN Phase-2 monthly figures).
  class WithholdingTaxCalculator < BaseCalculator
    agency "withholding_tax"

    SUPPORTED_PERIODS = %w[monthly].freeze

    private

    def validate!(monthly_taxable_income:, pay_period: "monthly")
      unless SUPPORTED_PERIODS.include?(pay_period.to_s)
        raise InvalidInput, "pay_period #{pay_period.inspect} not supported in v1 (only: #{SUPPORTED_PERIODS.join(', ')})"
      end

      raise InvalidInput, "monthly_taxable_income must not be negative" if bd(monthly_taxable_income).negative?
    end

    def compute(table, monthly_taxable_income:, pay_period: "monthly")
      income = bd(monthly_taxable_income)
      rows = table.fetch("monthly").fetch("brackets").map do |b|
        { over: bd(b["over"]), base: bd(b["base"]), rate: bd(b["rate"]) }
      end

      row = rows.select { |r| income >= r[:over] }.max_by { |r| r[:over] }
      tax = round_centavo(row[:base] + (income - row[:over]) * row[:rate])

      { withholding_tax: tax, bracket_floor: row[:over], bracket_rate: row[:rate] }
    end
  end
end
