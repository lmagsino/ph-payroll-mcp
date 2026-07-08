# frozen_string_literal: true

require "date"

RSpec.describe Payroll::RateTables do
  fixtures = File.expand_path("../fixtures", __dir__)
  valid_dir = File.join(fixtures, "contribution_tables")
  dup_dir = File.join(fixtures, "bad_duplicate")
  empty_dir = File.join(fixtures, "empty")

  # These specs mutate the module-level table set; reset it after each so other
  # specs (and lazy loads) fall back to the real config dir.
  after { described_class.instance_variable_set(:@tables, nil) }

  describe ".for effective-date selection" do
    before { described_class.reload!(valid_dir) }

    it "returns the latest table effective on or before the date" do
      table = described_class.for("philhealth", as_of: Date.new(2026, 8, 1))
      expect(table.effective_date).to eq(Date.new(2026, 7, 1))
      expect(table.source_circular).to eq("TEST Circular 2026 (mid-year)")
    end

    it "returns the earlier table for a date before the mid-year change" do
      table = described_class.for("philhealth", as_of: Date.new(2026, 6, 30))
      expect(table.effective_date).to eq(Date.new(2025, 1, 1))
    end

    it "returns the latest known table for a far-future date" do
      expect(described_class.for("philhealth", as_of: Date.new(2099, 1, 1)).effective_date)
        .to eq(Date.new(2026, 7, 1))
    end

    it "fails loud when no table is effective on or before the date" do
      expect { described_class.for("philhealth", as_of: Date.new(2020, 1, 1)) }
        .to raise_error(described_class::MissingRateTable, /available: 2025-01-01, 2026-07-01/)
    end

    it "parses a String as_of and rejects garbage" do
      expect(described_class.for("philhealth", as_of: "2025-06-01").effective_date).to eq(Date.new(2025, 1, 1))
      expect { described_class.for("philhealth", as_of: "not-a-date") }.to raise_error(Payroll::InvalidInput)
    end
  end

  describe ".load! configuration failures" do
    it "raises on duplicate effective_date within an agency" do
      expect { described_class.reload!(dup_dir) }
        .to raise_error(described_class::ConfigurationError, /duplicate effective_date/)
    end

    it "raises when the directory has no tables" do
      expect { described_class.reload!(empty_dir) }
        .to raise_error(described_class::ConfigurationError, /no rate tables found/)
    end
  end

  describe "the real seed config" do
    it "loads and validates every shipped table" do
      tables = described_class.reload!
      agencies = tables.map(&:agency).uniq
      expect(agencies).to contain_exactly("pagibig", "philhealth", "sss", "withholding_tax")
    end
  end
end
