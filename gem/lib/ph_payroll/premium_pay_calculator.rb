# frozen_string_literal: true

require_relative "base_calculator"
require_relative "table_schema"

module PhPayroll
  # Pay for one day's work by day type: ordinary, special working, special non-working,
  # regular holiday and their doubles, on or off the employee's rest day, with overtime
  # and night-shift hours. Multipliers come from the premium_pay table (DOLE Handbook).
  #
  #   regular pay        = daily_rate x day multiplier x hours_worked / 8
  #   overtime pay       = hourly x day multiplier x (1 + OT premium) x overtime_hours
  #   night differential = 10% of the rate of each night hour, regular or overtime
  #   not worked         = daily_rate x unworked multiplier
  #
  # The OT premium is 25% only on a day that carries no premium (multiplier 1); every
  # rest day, special day and holiday takes 30% of that day's rate (Art. 87).
  #
  # Unworked holiday pay assumes the employee is entitled to it: present or on paid leave
  # the workday before, and not in an excluded group (e.g. retail or service
  # establishments regularly employing fewer than ten workers). The caller knows that;
  # the calculator does not.
  class PremiumPayCalculator < BaseCalculator
    agency "premium_pay"

    private

    def validate!(daily_rate:, day_type:, rest_day: false, worked: true, hours_worked: nil,
                  overtime_hours: 0, night_hours: 0, night_overtime_hours: 0)
      validate_positive_finite!(daily_rate, field: "daily_rate")
      unless TableSchema::DAY_TYPES.include?(day_type.to_s)
        raise InvalidInput, "day_type must be one of #{TableSchema::DAY_TYPES.join(', ')}"
      end

      { rest_day: rest_day, worked: worked }.each do |field, value|
        raise InvalidInput, "#{field} must be true or false" unless [true, false].include?(value)
      end

      hours = { overtime_hours: overtime_hours, night_hours: night_hours, night_overtime_hours: night_overtime_hours }
      hours[:hours_worked] = hours_worked unless hours_worked.nil?
      hours.each { |field, value| raise InvalidInput, "#{field} cannot be negative" if bd(value).negative? }

      return if worked
      return if hours.values.all? { |v| bd(v).zero? }

      raise InvalidInput, "a day not worked cannot have hours; set worked: true or drop the hours"
    end

    def compute(table, daily_rate:, day_type:, rest_day: false, worked: true, hours_worked: nil,
                overtime_hours: 0, night_hours: 0, night_overtime_hours: 0)
      day_hours = table.decimal("hours_per_day")
      rate = bd(daily_rate)
      hourly = rate / day_hours
      multipliers = table.fetch("day_types").fetch(day_type.to_s)

      unless worked
        multiplier = bd(multipliers.fetch(rest_day ? "unworked_rest_day" : "unworked"))
        pay = round_centavo(rate * multiplier)
        return amounts(hourly, multiplier, pay, BigDecimal(0), BigDecimal(0))
      end

      hours = bd(hours_worked.nil? ? day_hours : hours_worked)
      overtime = bd(overtime_hours)
      night = bd(night_hours)
      night_overtime = bd(night_overtime_hours)
      check_hours!(hours, overtime, night, night_overtime, day_hours)

      multiplier = bd(multipliers.fetch(rest_day ? "worked_rest_day" : "worked"))
      premium = multiplier > 1 ? table.decimal("overtime_premium_premium_day") : table.decimal("overtime_premium_ordinary_day")
      overtime_multiplier = multiplier * (1 + premium)
      differential = table.decimal("night_differential")

      regular_pay = round_centavo(rate * multiplier * hours / day_hours)
      overtime_pay = round_centavo(hourly * overtime_multiplier * overtime)
      night_pay = round_centavo((hourly * multiplier * night + hourly * overtime_multiplier * night_overtime) * differential)
      amounts(hourly, multiplier, regular_pay, overtime_pay, night_pay)
    end

    def check_hours!(hours, overtime, night, night_overtime, day_hours)
      raise InvalidInput, "hours_worked must be between 0 and #{day_hours.to_i}" unless hours.positive? && hours <= day_hours
      if overtime.positive? && hours < day_hours
        raise InvalidInput, "overtime_hours count only after a full #{day_hours.to_i}-hour day"
      end
      raise InvalidInput, "night_hours cannot exceed hours_worked" if night > hours
      raise InvalidInput, "night_overtime_hours cannot exceed overtime_hours" if night_overtime > overtime
    end

    def amounts(hourly, multiplier, regular_pay, overtime_pay, night_pay)
      {
        hourly_rate: round_centavo(hourly),
        day_multiplier: multiplier,
        regular_pay: regular_pay,
        overtime_pay: overtime_pay,
        night_differential: night_pay,
        total: regular_pay + overtime_pay + night_pay
      }
    end
  end
end
