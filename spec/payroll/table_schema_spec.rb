# frozen_string_literal: true

require "date"

RSpec.describe Payroll::TableSchema do
  def table(agency: "philhealth", effective_date: Date.new(2026, 1, 1),
            source_circular: "TEST", data: { "rate" => "0.05" })
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
    expect { described_class.validate!(table(data: { "rate" => "five percent" })) }
      .to raise_error(described_class::Invalid, /not numeric/)
  end

  it "allows nested (Hash/Array) data values without numeric checks" do
    expect { described_class.validate!(table(data: { "brackets" => [{ "over" => "0" }] })) }.not_to raise_error
  end

  it "rejects empty data" do
    expect { described_class.validate!(table(data: {})) }
      .to raise_error(described_class::Invalid, /non-empty Hash/)
  end
end
