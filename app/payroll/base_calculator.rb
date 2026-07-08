# frozen_string_literal: true

require "bigdecimal"
require "date"
require_relative "errors"
require_relative "result"
require_relative "rate_tables"

module Payroll
  # Abstract base for every agency calculator. Subclasses declare their agency and
  # implement #compute; the base handles the cross-cutting mechanics so tools stay
  # thin and the math stays DRY:
  #
  #   class SssCalculator < BaseCalculator
  #     agency "sss"
  #     private
  #     def compute(table, monthly_salary:, member_type:) ... end
  #   end
  #
  #   SssCalculator.new.call(monthly_salary: 30_000, member_type: "employed")
  #     #=> Payroll::Result stamped with the table's effective_date + source_circular
  #
  # Guarantees by construction: the right table is fetched by effective_date, input
  # is validated before compute, and the result carries the citation.
  class BaseCalculator
    def self.agency(name = nil)
      @agency = name.to_s if name
      @agency
    end

    def call(as_of: Date.today, **inputs)
      table = RateTables.for(self.class.agency, as_of: as_of)
      validate!(**inputs)
      result(compute(table, **inputs), table)
    end

    private

    # Subclasses override. Return a Hash of amount-name => BigDecimal.
    def compute(_table, **_inputs)
      raise NotImplementedError, "#{self.class} must implement #compute(table, **inputs)"
    end

    # Subclasses override to reject semantically invalid input. Default: no-op.
    def validate!(**_inputs); end

    def result(amounts, table)
      Result.new(amounts: amounts, effective_date: table.effective_date, source_circular: table.source_circular)
    end

    # --- shared math helpers (BigDecimal + explicit HALF_UP rounding) ---

    # Coerce to BigDecimal; raise InvalidInput on garbage or non-finite input.
    def bd(value)
      case value
      when BigDecimal then value
      when Integer then BigDecimal(value)
      when Float
        raise InvalidInput, "value #{value} is not finite" unless value.finite?

        BigDecimal(value.to_s)
      when String
        begin
          BigDecimal(value)
        rescue ArgumentError
          raise InvalidInput, "#{value.inspect} is not a valid number"
        end
      else
        raise InvalidInput, "cannot coerce #{value.class} to a number"
      end
    end

    def round_centavo(amount)
      bd(amount).round(2, BigDecimal::ROUND_HALF_UP)
    end

    # Clamp a valid positive value to a legal statutory range. NEVER used to
    # sanitize invalid input — that is validate!'s job (reject, don't coerce).
    def clamp(value, floor:, ceiling:)
      f = bd(floor)
      c = bd(ceiling)
      raise InvalidInput, "floor #{f.to_s('F')} exceeds ceiling #{c.to_s('F')}" if f > c

      v = bd(value)
      return f if v < f
      return c if v > c

      v
    end

    # Validate and return a positive, finite amount. Raises InvalidInput otherwise.
    def validate_positive_finite!(value, field:)
      v = bd(value)
      raise InvalidInput, "#{field} must be greater than zero" if v <= 0

      v
    end
  end
end
