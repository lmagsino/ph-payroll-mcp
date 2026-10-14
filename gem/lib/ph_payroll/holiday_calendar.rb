# frozen_string_literal: true

require "date"
require_relative "errors"
require_relative "rate_tables"

module PhPayroll
  # Answers "what kind of day is this date?" from the nationwide holiday calendar.
  #
  #   HolidayCalendar.day("2026-04-09")
  #     #=> Day(date: 2026-04-09, day_type: "regular_holiday", names: ["Araw ng Kagitingan"],
  #            sources: ["Proclamation No. 1006"], source_circular: "Proclamation No. 1006, ...")
  #
  # A calendar answers only for its own year. RateTables would hand a 2027 date the
  # latest table, i.e. the 2026 calendar, and call 2027's holidays ordinary days; the
  # year check refuses instead, because a wrong day type is a wrong amount.
  module HolidayCalendar
    Day = Data.define(:date, :day_type, :names, :sources, :source_circular)

    class << self
      def day(date)
        date = coerce_date(date)
        table = table_for(date.year)
        entries = table.fetch("dates").select { |entry| Date.iso8601(entry["date"].to_s) == date }
        build_day(date, entries, table)
      end

      # Every listed date in the year, in date order.
      def year(year)
        table = table_for(year.to_i)
        table.fetch("dates")
             .group_by { |entry| Date.iso8601(entry["date"].to_s) }
             .sort_by(&:first)
             .map { |date, entries| build_day(date, entries, table) }
      end

      private

      def table_for(year)
        table = RateTables.for("holidays", as_of: Date.new(year, 12, 31))
        return table if table.fetch("year").to_i == year

        raise RateTables::MissingRateTable,
              "no #{year} holiday calendar is loaded (latest covers #{table.fetch('year')})"
      end

      def build_day(date, entries, table)
        Day.new(date: date, day_type: day_type(entries), names: entries.map { |e| e["name"] },
                sources: entries.map { |e| e["source"] }.compact.uniq, source_circular: table.source_circular)
      end

      # A regular holiday outranks a special day falling on the same date; two of the
      # same kind make a double.
      def day_type(entries)
        types = entries.map { |e| e["type"] }
        regular = types.count("regular_holiday")
        special = types.count("special_non_working")

        if regular >= 2 then "double_holiday"
        elsif regular == 1 then "regular_holiday"
        elsif special >= 2 then "double_special_non_working"
        elsif special == 1 then "special_non_working"
        elsif types.include?("special_working") then "special_working"
        else "ordinary"
        end
      end

      def coerce_date(value)
        case value
        when Date then value
        when String then Date.iso8601(value)
        else raise InvalidInput, "invalid date: #{value.inspect}"
        end
      rescue Date::Error
        raise InvalidInput, "invalid date: #{value.inspect}"
      end
    end
  end
end
