# frozen_string_literal: true

require "bigdecimal"
require_relative "errors"

module Payroll
  # Validates the shape of a rate Table. Runs at boot (via RateTables.load!) so a
  # bad table never serves traffic, AND in CI (via bin/validate_tables) so a bad
  # data PR never merges — same code, two entry points.
  #
  # v1 enforces the citation contract (known agency, effective_date, source_circular)
  # and that scalar data values parse to BigDecimal. Per-agency required-key maps
  # arrive in M2 as each calculator defines the keys it consumes.
  module TableSchema
    class Invalid < Payroll::Error; end

    KNOWN_AGENCIES = %w[sss philhealth pagibig withholding_tax thirteenth_month].freeze

    # Per-agency required data keys. Each M2 calculator ticket adds its agency's
    # keys as it lands, so a table missing a rate/threshold fails at boot AND in CI.
    REQUIRED_KEYS = {
      "philhealth" => %w[rate floor ceiling],
      "pagibig" => %w[low_rate_ee rate_ee rate_er low_threshold ceiling],
      "sss" => %w[msc_floor msc_ceiling msc_step ofw_msc_floor wisp_threshold
                  rate_total rate_employer rate_employee ec_low ec_high ec_threshold],
      "withholding_tax" => %w[monthly],
      "thirteenth_month" => %w[exempt_threshold]
    }.freeze

    def self.validate!(table)
      loc = "#{table.agency} #{table.effective_date}"

      unless KNOWN_AGENCIES.include?(table.agency)
        raise Invalid, "#{loc}: unknown agency #{table.agency.inspect} (known: #{KNOWN_AGENCIES.join(', ')})"
      end
      raise Invalid, "#{loc}: missing effective_date" if table.effective_date.nil?

      if table.source_circular.nil? || table.source_circular.to_s.strip.empty?
        raise Invalid, "#{loc}: missing source_circular — the citation is mandatory"
      end
      raise Invalid, "#{loc}: data must be a non-empty Hash" unless table.data.is_a?(Hash) && !table.data.empty?

      table.data.each do |key, value|
        next if value.is_a?(Hash) || value.is_a?(Array) # nested shapes (brackets) validated per-agency in M2

        begin
          BigDecimal(value.to_s)
        rescue ArgumentError
          raise Invalid, "#{loc}: value for #{key.inspect} is not numeric: #{value.inspect}"
        end
      end

      missing = (REQUIRED_KEYS[table.agency] || []).reject { |k| table.data.key?(k) }
      raise Invalid, "#{loc}: missing required keys: #{missing.join(', ')}" unless missing.empty?

      table
    end
  end
end
