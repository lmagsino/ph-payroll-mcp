# frozen_string_literal: true

require_relative "base_tool"

module Tools
  class ComputeHolidayPay < BaseTool
    ASSUMPTIONS = [
      "Unworked regular-holiday pay assumes the employee was present, or on paid leave, on the " \
      "workday before the holiday (DOLE Handbook 2024, §2.E).",
      "Holiday pay does not cover retail and service establishments regularly employing fewer than " \
      "ten workers, managerial employees, or field personnel, among others (DOLE Handbook 2024, §2.B).",
      "Special non-working days are 'no work, no pay' unless a company policy or CBA grants more.",
      "The holiday calendar is nationwide; regional and local special days are not included."
    ].freeze

    tool_name "compute_holiday_pay"
    description "Compute one day's pay for a Philippine daily-paid employee on an ordinary day, " \
                "rest day, special non-working day, special working day, regular holiday or double " \
                "holiday, with overtime and night-shift hours. Give a date (the official holiday " \
                "calendar decides the day type) or a day_type. Returns regular pay, overtime pay, " \
                "night differential and total, cited to the DOLE Handbook, plus the holiday name and " \
                "proclamation when a date is given, and the eligibility assumptions to relay."

    input_schema(
      properties: {
        daily_rate: MONEY.merge(description: "Basic daily wage in PHP"),
        date: { type: "string", format: "date", description: "ISO date (YYYY-MM-DD); use this or day_type" },
        day_type: { type: "string", enum: PhPayroll::TableSchema::DAY_TYPES, description: "Use this or date" },
        rest_day: { type: "boolean", default: false, description: "The day is the employee's scheduled rest day" },
        worked: { type: "boolean", default: true, description: "false for holiday pay on a day not worked" },
        hours_worked: { type: "number", default: 8, description: "Regular hours worked, up to 8" },
        overtime_hours: { type: "number", default: 0, description: "Hours beyond 8" },
        night_hours: { type: "number", default: 0, description: "Regular hours between 10 pm and 6 am" },
        night_overtime_hours: { type: "number", default: 0, description: "Overtime hours between 10 pm and 6 am" }
      },
      required: %w[daily_rate],
      additionalProperties: false
    )

    class << self
      def call(daily_rate:, date: nil, day_type: nil, **hours_and_flags)
        domain do
          day = date && PhPayroll::HolidayCalendar.day(date)
          inputs = { daily_rate: daily_rate, **hours_and_flags }
          inputs[:date] = date if date
          inputs[:day_type] = day_type if day_type
          result = PhPayroll::PremiumPayCalculator.new.call(**inputs)

          result.to_h.merge(
            day_type: day ? day.day_type : day_type,
            rest_day: hours_and_flags.fetch(:rest_day, false),
            worked: hours_and_flags.fetch(:worked, true),
            holidays: day ? day.names : [],
            holiday_sources: day ? day.sources : [],
            assumptions: ASSUMPTIONS
          )
        end
      end
    end
  end
end
