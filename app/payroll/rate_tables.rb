# frozen_string_literal: true

require "yaml"
require "date"
require_relative "errors"
require_relative "table"
require_relative "table_schema"

module Payroll
  # Loads versioned rate tables from YAML once at boot and selects the one in
  # effect for a given date.
  #
  #   RateTables.for("philhealth", as_of: Date.new(2026, 8, 1))
  #     => the latest table whose effective_date <= 2026-08-01
  #
  # Selection is by effective_date, not year, so a mid-year rate change resolves
  # correctly. A request with no table on or before the date fails loud
  # (MissingRateTable) rather than silently serving the wrong period — the whole
  # point of the project.
  module RateTables
    class MissingRateTable < Payroll::Error; end
    class ConfigurationError < Payroll::Error; end

    DEFAULT_DIR = File.expand_path("../../config/contribution_tables", __dir__)

    class << self
      # Load, validate, sort, and freeze all tables. Raises on empty dir, duplicate
      # effective_dates within an agency, malformed YAML, or schema violation.
      def load!(dir = DEFAULT_DIR)
        files = Dir.glob(File.join(dir, "*.yml")).sort
        raise ConfigurationError, "no rate tables found in #{dir}" if files.empty?

        tables = files.flat_map { |path| load_file(path) }

        tables.group_by(&:agency).each do |agency, list|
          dates = list.map(&:effective_date)
          raise ConfigurationError, "#{agency}: duplicate effective_date among tables" if dates.uniq.length != dates.length
        end

        @tables = tables.sort_by { |t| [t.agency, t.effective_date] }.freeze
      end

      def reload!(dir = DEFAULT_DIR)
        @tables = nil
        load!(dir)
      end

      def all
        @tables || load!
      end

      def for(agency, as_of: Date.today)
        agency = agency.to_s
        as_of = coerce_date(as_of)

        table = all.select { |t| t.agency == agency && t.effective_date <= as_of }
                   .max_by(&:effective_date)
        return table if table

        available = all.select { |t| t.agency == agency }.map { |t| t.effective_date.iso8601 }
        detail = available.empty? ? "no tables for this agency" : "available: #{available.join(', ')}"
        raise MissingRateTable, "no #{agency} rate table effective on or before #{as_of.iso8601}; #{detail}"
      end

      private

      def load_file(path)
        raw = YAML.safe_load_file(path, permitted_classes: [Date])
        agency = raw.fetch("agency")

        raw.fetch("tables").map do |entry|
          table = Table.new(
            agency: agency,
            effective_date: coerce_date(entry.fetch("effective_date")),
            source_circular: entry["source_circular"],
            data: entry["data"]
          )
          TableSchema.validate!(table)
          table
        end
      rescue KeyError => e
        raise ConfigurationError, "#{File.basename(path)}: #{e.message}"
      end

      def coerce_date(value)
        case value
        when Date then value
        when String then Date.iso8601(value)
        else raise InvalidInput, "invalid date: #{value.inspect}"
        end
      rescue ArgumentError
        raise InvalidInput, "invalid date: #{value.inspect}"
      end
    end
  end
end
