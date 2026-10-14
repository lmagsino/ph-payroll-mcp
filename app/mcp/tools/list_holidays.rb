# frozen_string_literal: true

require_relative "base_tool"

module Tools
  class ListHolidays < BaseTool
    tool_name "list_holidays"
    description "List the Philippine nationwide regular holidays, special non-working days and " \
                "special working days for a year, each with its type and the proclamation that " \
                "declared it. Use it to check which days in a pay period carry premium pay."

    input_schema(
      properties: { year: { type: "integer", description: "Calendar year, e.g. 2026" } },
      required: %w[year],
      additionalProperties: false
    )

    class << self
      def call(year:)
        domain do
          days = PhPayroll::HolidayCalendar.year(year)
          {
            year: year,
            source_circular: days.first&.source_circular,
            holidays: days.map do |day|
              { date: day.date, day_type: day.day_type, names: day.names, sources: day.sources }
            end
          }
        end
      end
    end
  end
end
