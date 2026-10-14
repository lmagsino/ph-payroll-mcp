# frozen_string_literal: true

require "bigdecimal"

# Golden values derived by hand from the DOLE Handbook 2024 "Guide Computations" rows,
# never read back from premium_pay.yml. A ₱800 daily rate makes the hourly rate ₱100,
# so each figure is the Handbook multiple times 100 per hour, or times 800 per day.
RSpec.describe PhPayroll::PremiumPayCalculator do
  subject(:calc) { described_class.new }

  let(:daily_rate) { 800 }

  def pay(**inputs) = calc.call(daily_rate: daily_rate, **inputs).amounts

  describe "a full worked day" do
    {
      ["ordinary", false] => "800.00",                     # 1.00 x 800
      ["ordinary", true] => "1040.00",                     # rest day 1.30
      ["special_working", false] => "800.00",              # counts as an ordinary workday
      ["special_non_working", false] => "1040.00",         # 1.30
      ["special_non_working", true] => "1200.00",          # 1.50
      ["double_special_non_working", false] => "1200.00",  # 1.50
      ["double_special_non_working", true] => "1560.00",   # 1.95
      ["regular_holiday", false] => "1600.00",             # 2.00
      ["regular_holiday", true] => "2080.00",              # 2.60
      ["double_holiday", false] => "2400.00",              # 3.00
      ["double_holiday", true] => "3120.00"                # 3.90
    }.each do |(day_type, rest_day), expected|
      it "#{day_type}#{' on a rest day' if rest_day} pays #{expected}" do
        expect(pay(day_type: day_type, rest_day: rest_day)[:regular_pay]).to eq(BigDecimal(expected))
      end
    end

    it "carries the Handbook citation" do
      result = calc.call(daily_rate: daily_rate, day_type: "regular_holiday")
      expect(result.source_circular).to match(/Handbook on Workers' Statutory Monetary Benefits, 2024/)
    end
  end

  describe "overtime" do
    it "is 125% of the hourly rate on an ordinary day" do
      expect(pay(day_type: "ordinary", overtime_hours: 2)[:overtime_pay]).to eq(BigDecimal("250.00")) # 2 x 125
    end

    it "is 30% on top of the day's rate on a rest day" do
      expect(pay(day_type: "ordinary", rest_day: true, overtime_hours: 1)[:overtime_pay]).to eq(BigDecimal("169.00"))
    end

    it "compounds on a regular holiday: 2.0 x 1.3" do
      a = pay(day_type: "regular_holiday", overtime_hours: 2)
      expect(a[:overtime_pay]).to eq(BigDecimal("520.00")) # 2 x 260
      expect(a[:total]).to eq(BigDecimal("2120.00"))
    end

    it "compounds on a regular holiday that is the rest day: 2.6 x 1.3" do
      expect(pay(day_type: "regular_holiday", rest_day: true, overtime_hours: 1)[:overtime_pay])
        .to eq(BigDecimal("338.00"))
    end

    it "is 125% on a special working day, like an ordinary day" do
      expect(pay(day_type: "special_working", overtime_hours: 1)[:overtime_pay]).to eq(BigDecimal("125.00"))
    end
  end

  describe "night shift differential" do
    it "adds 10% of the hourly rate on an ordinary day" do
      expect(pay(day_type: "ordinary", night_hours: 2)[:night_differential]).to eq(BigDecimal("20.00"))
    end

    it "adds 10% of the holiday rate on a regular holiday (2.0 x 1.1 = 2.2 an hour)" do
      a = pay(day_type: "regular_holiday", night_hours: 8)
      expect(a[:night_differential]).to eq(BigDecimal("160.00"))
      expect(a[:total]).to eq(BigDecimal("1760.00")) # 8 x 220
    end

    it "adds 10% of the overtime rate on a night overtime hour (1.25 x 1.1 = 1.375)" do
      a = pay(day_type: "ordinary", overtime_hours: 1, night_overtime_hours: 1)
      expect(a[:overtime_pay]).to eq(BigDecimal("125.00"))
      expect(a[:night_differential]).to eq(BigDecimal("12.50"))
    end

    it "compounds on a regular holiday night overtime hour (2.0 x 1.3 x 1.1 = 2.86)" do
      a = pay(day_type: "regular_holiday", overtime_hours: 1, night_overtime_hours: 1)
      expect(a[:overtime_pay] + a[:night_differential]).to eq(BigDecimal("286.00"))
    end
  end

  describe "a part day" do
    it "prorates the first eight hours" do
      expect(pay(day_type: "special_non_working", hours_worked: 4)[:regular_pay]).to eq(BigDecimal("520.00"))
    end
  end

  describe "a day not worked" do
    it "pays 100% on a regular holiday" do
      expect(pay(day_type: "regular_holiday", worked: false)[:total]).to eq(BigDecimal("800.00"))
    end

    it "pays 200% on a double holiday" do
      expect(pay(day_type: "double_holiday", worked: false)[:total]).to eq(BigDecimal("1600.00"))
    end

    it "pays nothing on a special non-working day (no work, no pay)" do
      expect(pay(day_type: "special_non_working", worked: false)[:total]).to eq(BigDecimal("0"))
    end
  end

  describe "by date" do
    it "prices a calendar holiday as that holiday (Araw ng Kagitingan, 9 Apr 2026)" do
      expect(pay(date: "2026-04-09")[:regular_pay]).to eq(BigDecimal("1600.00"))
    end

    it "prices an unlisted date as an ordinary day" do
      expect(pay(date: "2026-04-08", overtime_hours: 1)[:overtime_pay]).to eq(BigDecimal("125.00"))
    end

    it "still applies the rest-day flag (All Saints' Day falls on Sunday 1 Nov 2026)" do
      expect(pay(date: "2026-11-01", rest_day: true)[:regular_pay]).to eq(BigDecimal("1200.00")) # 1.50
    end

    it "rejects a date together with a day type" do
      expect { pay(date: "2026-04-09", day_type: "ordinary") }
        .to raise_error(PhPayroll::InvalidInput, /either date or day_type/)
    end

    it "refuses a date with no calendar" do
      expect { pay(date: "2027-04-09") }.to raise_error(PhPayroll::RateTables::MissingRateTable)
    end
  end

  describe "invalid input" do
    it "rejects an unknown day type" do
      expect { pay(day_type: "holiday") }.to raise_error(PhPayroll::InvalidInput, /day_type must be one of/)
    end

    it "rejects a non-positive daily rate" do
      expect { calc.call(daily_rate: 0, day_type: "ordinary") }.to raise_error(PhPayroll::InvalidInput)
    end

    it "rejects overtime before a full day" do
      expect { pay(day_type: "ordinary", hours_worked: 6, overtime_hours: 1) }
        .to raise_error(PhPayroll::InvalidInput, /after a full 8-hour day/)
    end

    it "rejects more than eight regular hours" do
      expect { pay(day_type: "ordinary", hours_worked: 9) }.to raise_error(PhPayroll::InvalidInput, /between 0 and 8/)
    end

    it "rejects more night hours than hours worked" do
      expect { pay(day_type: "ordinary", hours_worked: 4, night_hours: 5) }
        .to raise_error(PhPayroll::InvalidInput, /night_hours cannot exceed/)
    end

    it "rejects hours on a day not worked" do
      expect { pay(day_type: "regular_holiday", worked: false, overtime_hours: 1) }
        .to raise_error(PhPayroll::InvalidInput, /not worked cannot have hours/)
    end

    it "rejects a non-boolean rest_day" do
      expect { pay(day_type: "ordinary", rest_day: "yes") }.to raise_error(PhPayroll::InvalidInput, /rest_day/)
    end
  end
end
