# frozen_string_literal: true

require "bigdecimal"
require "date"
require_relative "errors"

module PhPayroll
  # Validates the shape of a rate Table. Runs at boot (via RateTables.load!) so a
  # bad table never serves traffic, AND in CI (via bin/validate_tables) so a bad
  # data PR never merges — same code, two entry points.
  #
  # v1 enforces the citation contract (known agency, effective_date, source_circular)
  # and that scalar data values parse to BigDecimal. Per-agency required-key maps
  # arrive in M2 as each calculator defines the keys it consumes.
  module TableSchema
    class Invalid < PhPayroll::Error; end

    KNOWN_AGENCIES = %w[sss philhealth pagibig withholding_tax thirteenth_month premium_pay holidays].freeze

    # Day types a premium-pay table prices. The two doubles never appear in a holiday
    # calendar: they are two holidays of the same kind falling on one date.
    DAY_TYPES = %w[ordinary special_working special_non_working double_special_non_working
                   regular_holiday double_holiday].freeze
    CALENDAR_DAY_TYPES = %w[special_working special_non_working regular_holiday].freeze
    MULTIPLIER_KEYS = %w[worked worked_rest_day unworked unworked_rest_day].freeze

    # Per-agency required data keys. Each M2 calculator ticket adds its agency's
    # keys as it lands, so a table missing a rate/threshold fails at boot AND in CI.
    REQUIRED_KEYS = {
      "philhealth" => %w[rate floor ceiling],
      "pagibig" => %w[low_rate_ee rate_ee rate_er low_threshold ceiling],
      "sss" => %w[msc_floor msc_ceiling msc_step ofw_msc_floor wisp_threshold
                  rate_total rate_employer rate_employee ec_low ec_high ec_threshold],
      "withholding_tax" => %w[monthly],
      "thirteenth_month" => %w[exempt_threshold],
      "premium_pay" => %w[hours_per_day overtime_premium_ordinary_day overtime_premium_premium_day
                          night_differential day_types],
      "holidays" => %w[year dates]
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

      case table.agency
      when "premium_pay" then validate_day_types!(loc, table.data["day_types"])
      when "holidays" then validate_dates!(loc, table.data["year"], table.data["dates"])
      end

      table
    end

    def self.validate_day_types!(loc, day_types)
      raise Invalid, "#{loc}: day_types must be a Hash" unless day_types.is_a?(Hash)

      unless day_types.keys.sort == DAY_TYPES.sort
        raise Invalid, "#{loc}: day_types must price exactly #{DAY_TYPES.join(', ')}"
      end

      day_types.each do |type, multipliers|
        unless multipliers.is_a?(Hash) && multipliers.keys.sort == MULTIPLIER_KEYS.sort
          raise Invalid, "#{loc}: #{type} needs exactly #{MULTIPLIER_KEYS.join(', ')}"
        end

        multipliers.each do |key, value|
          BigDecimal(value.to_s)
        rescue ArgumentError
          raise Invalid, "#{loc}: #{type}.#{key} is not numeric: #{value.inspect}"
        end
      end
    end

    # Each entry dates one holiday within the table's year, so a calendar can never
    # answer for a year it does not cover.
    def self.validate_dates!(loc, year, dates)
      raise Invalid, "#{loc}: dates must be a non-empty Array" unless dates.is_a?(Array) && !dates.empty?

      dates.each do |entry|
        raise Invalid, "#{loc}: each date entry must be a Hash" unless entry.is_a?(Hash)

        date = begin
          Date.iso8601(entry["date"].to_s)
        rescue Date::Error
          raise Invalid, "#{loc}: invalid date #{entry['date'].inspect}"
        end
        raise Invalid, "#{loc}: #{date} is outside year #{year}" unless date.year == year.to_i
        raise Invalid, "#{loc}: #{date} has no name" if entry["name"].to_s.strip.empty?

        unless CALENDAR_DAY_TYPES.include?(entry["type"])
          raise Invalid, "#{loc}: #{date} type must be one of #{CALENDAR_DAY_TYPES.join(', ')}"
        end
      end
    end

    private_class_method :validate_day_types!, :validate_dates!
  end
end
