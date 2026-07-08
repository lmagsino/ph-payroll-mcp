# frozen_string_literal: true

require "date"

RSpec.describe Payroll::TableSchema do
  # Default data satisfies philhealth's required keys (rate/floor/ceiling).
  def table(agency: "philhealth", effective_date: Date.new(2026, 1, 1), source_circular: "TEST",
            data: { "rate" => "0.05", "floor" => "10000", "ceiling" => "100000" })
    Payroll::Table.new(agency: agency, effective_date: effective_date,
                       source_circular: source_circular, data: data)
  end

  it "passes a well-formed table" do
    expect(described_class.validate!(table)).to be_a(Payroll::Table)
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
end
