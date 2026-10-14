# frozen_string_literal: true

require "date"

RSpec.describe PhPayroll::TableSchema do
  # Default data satisfies philhealth's required keys (rate/floor/ceiling).
  def table(agency: "philhealth", effective_date: Date.new(2026, 1, 1), source_circular: "TEST",
            data: { "rate" => "0.05", "floor" => "10000", "ceiling" => "100000" })
    PhPayroll::Table.new(agency: agency, effective_date: effective_date,
                       source_circular: source_circular, data: data)
  end

  it "passes a well-formed table" do
    expect(described_class.validate!(table)).to be_a(PhPayroll::Table)
  end

  it "rejects an unknown agency" do
    expect { described_class.validate!(table(agency: "gsis")) }
      .to raise_error(described_class::Invalid, /unknown agency/)
  end

  it "rejects a missing effective_date" do
    expect { described_class.validate!(table(effective_date: nil)) }
      .to raise_error(described_class::Invalid, /missing effective_date/)
  end

  it "rejects a blank source_circular" do
    expect { described_class.validate!(table(source_circular: "   ")) }
      .to raise_error(described_class::Invalid, /missing source_circular/)
  end

  it "rejects a non-numeric scalar data value" do
    expect { described_class.validate!(table(data: { "rate" => "five", "floor" => "10000", "ceiling" => "100000" })) }
      .to raise_error(described_class::Invalid, /not numeric/)
  end

  it "rejects a table missing a per-agency required key" do
    expect { described_class.validate!(table(data: { "rate" => "0.05" })) }
      .to raise_error(described_class::Invalid, /missing required keys: floor, ceiling/)
  end

  it "allows nested (Hash/Array) data values without numeric checks" do
    # withholding_tax has no strict required-key set yet; `monthly` is a nested Hash.
    nested = table(agency: "withholding_tax", data: { "monthly" => { "brackets" => [{ "over" => "0" }] } })
    expect { described_class.validate!(nested) }.not_to raise_error
  end

  it "rejects empty data" do
    expect { described_class.validate!(table(data: {})) }
      .to raise_error(described_class::Invalid, /non-empty Hash/)
  end

  describe "premium_pay" do
    let(:multipliers) do
      { "worked" => "1", "worked_rest_day" => "1.3", "unworked" => "0", "unworked_rest_day" => "0" }
    end
    let(:data) do
      { "hours_per_day" => "8", "overtime_premium_ordinary_day" => "0.25",
        "overtime_premium_premium_day" => "0.30", "night_differential" => "0.10",
        "day_types" => described_class::DAY_TYPES.to_h { |type| [type, multipliers] } }
    end

    it "passes a table that prices every day type" do
      expect { described_class.validate!(table(agency: "premium_pay", data: data)) }.not_to raise_error
    end

    it "rejects a table missing a day type" do
      data["day_types"].delete("double_holiday")
      expect { described_class.validate!(table(agency: "premium_pay", data: data)) }
        .to raise_error(described_class::Invalid, /must price exactly/)
    end

    it "rejects a day type missing a multiplier" do
      data["day_types"]["regular_holiday"] = multipliers.except("unworked_rest_day")
      expect { described_class.validate!(table(agency: "premium_pay", data: data)) }
        .to raise_error(described_class::Invalid, /regular_holiday needs exactly/)
    end

    it "rejects a non-numeric multiplier" do
      data["day_types"]["ordinary"] = multipliers.merge("worked" => "double")
      expect { described_class.validate!(table(agency: "premium_pay", data: data)) }
        .to raise_error(described_class::Invalid, /ordinary.worked is not numeric/)
    end
  end

  describe "holidays" do
    def calendar(dates, year: "2026")
      table(agency: "holidays", data: { "year" => year, "dates" => dates })
    end

    let(:new_year) { { "date" => "2026-01-01", "name" => "New Year's Day", "type" => "regular_holiday" } }

    it "passes a dated calendar" do
      expect { described_class.validate!(calendar([new_year])) }.not_to raise_error
    end

    it "rejects a date outside the calendar's year" do
      expect { described_class.validate!(calendar([new_year.merge("date" => "2027-01-01")])) }
        .to raise_error(described_class::Invalid, /outside year 2026/)
    end

    it "rejects an unknown day type" do
      expect { described_class.validate!(calendar([new_year.merge("type" => "double_holiday")])) }
        .to raise_error(described_class::Invalid, /type must be one of/)
    end

    it "rejects an unparseable date" do
      expect { described_class.validate!(calendar([new_year.merge("date" => "2026-02-30")])) }
        .to raise_error(described_class::Invalid, /invalid date/)
    end

    it "rejects an unnamed holiday" do
      expect { described_class.validate!(calendar([new_year.merge("name" => " ")])) }
        .to raise_error(described_class::Invalid, /has no name/)
    end
  end
end
