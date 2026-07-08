# frozen_string_literal: true

require "bigdecimal"
require "date"

module Payroll
  # Immutable result of a calculation. The ONE place the citation contract lives:
  # every calculation returns amounts alongside the effective_date and
  # source_circular of the rate table used, so no number ever ships uncited.
  #
  #   Result(amounts: {employee_share: BigDecimal, ...},
  #          effective_date: Date, source_circular: "SSS Circular ...")
  #
  # #to_h serializes for MCP JSON: amounts as 2-decimal numbers, an ISO date,
  # the verbatim circular, and an `as_of` sentence the LLM can echo directly.
  class Result < Data.define(:amounts, :effective_date, :source_circular)
    def initialize(amounts:, effective_date:, source_circular:)
      raise ArgumentError, "effective_date is required" if effective_date.nil?

      if source_circular.nil? || source_circular.to_s.strip.empty?
        raise ArgumentError, "source_circular is required — a number must never ship uncited"
      end
      raise ArgumentError, "amounts must be a non-empty Hash" unless amounts.is_a?(Hash) && !amounts.empty?

      amounts.each do |key, value|
        unless value.is_a?(BigDecimal)
          raise ArgumentError, "amount #{key.inspect} must be BigDecimal, got #{value.class}"
        end
      end

      super(amounts: amounts.freeze, effective_date: effective_date, source_circular: source_circular.to_s)
    end

    # Money as 2-decimal numbers (BigDecimal kept internally; rounded HALF_UP at the
    # boundary). LLMs parse numbers more reliably than money-strings; values are small
    # so 2dp is exact for display. Switch to strings if a consumer ever needs exactness.
    def to_h
      amounts.transform_values { |v| v.round(2, BigDecimal::ROUND_HALF_UP).to_f }
             .merge(
               effective_date: effective_date.iso8601,
               source_circular: source_circular,
               as_of: "as of #{effective_date.iso8601}, per #{source_circular}"
             )
    end
  end
end
