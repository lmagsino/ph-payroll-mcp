# frozen_string_literal: true

require "bigdecimal"
require "date"

module Payroll
  # One versioned rate table entry: an agency's rules effective from a given date,
  # with the citation and the raw data map. Frozen value object.
  #
  #   Table(agency: "philhealth", effective_date: Date, source_circular: "...",
  #         data: { "rate" => "0.05", "floor" => "10000", ... })
  #
  # Rates are stored as strings in YAML and coerced to BigDecimal on read, so the
  # money path is exact end to end (never a Float from YAML parsing).
  class Table < Data.define(:agency, :effective_date, :source_circular, :data)
    # Raw value for a key (String/Hash/Array as stored). Raises if absent — a
    # missing key is a data bug, not a nil to paper over.
    def fetch(key)
      data.fetch(key.to_s) { raise KeyError, "#{agency} #{effective_date}: missing data key #{key.inspect}" }
    end

    # BigDecimal value for a scalar rate key.
    def decimal(key)
      BigDecimal(fetch(key).to_s)
    end
  end
end
