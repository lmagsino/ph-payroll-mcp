# frozen_string_literal: true

require "bigdecimal"
require "date"

RSpec.describe Payroll::Result do
  let(:amounts) { { employee_share: BigDecimal("1234.565"), employer_share: BigDecimal("1234.565") } }
  let(:date) { Date.new(2026, 1, 1) }

  subject(:result) do
    described_class.new(amounts: amounts, effective_date: date, source_circular: "SSS Circular 2026-001")
  end

  describe "#to_h" do
    it "rounds amounts HALF_UP to 2 decimals as numbers" do
      expect(result.to_h[:employee_share]).to eq(1234.57)
    end

    it "includes the ISO effective_date and verbatim source_circular" do
      expect(result.to_h[:effective_date]).to eq("2026-01-01")
      expect(result.to_h[:source_circular]).to eq("SSS Circular 2026-001")
    end

    it "includes a human-readable as_of citation the LLM can echo" do
      expect(result.to_h[:as_of]).to eq("as of 2026-01-01, per SSS Circular 2026-001")
    end
  end

  describe "citation contract" do
    it "raises when source_circular is blank" do
      expect do
        described_class.new(amounts: amounts, effective_date: date, source_circular: "  ")
      end.to raise_error(ArgumentError, /source_circular is required/)
    end

    it "raises when effective_date is nil" do
      expect do
        described_class.new(amounts: amounts, effective_date: nil, source_circular: "X")
      end.to raise_error(ArgumentError, /effective_date is required/)
    end

    it "raises when an amount is not a BigDecimal" do
      expect do
        described_class.new(amounts: { share: 1234.56 }, effective_date: date, source_circular: "X")
      end.to raise_error(ArgumentError, /must be BigDecimal/)
    end

    it "raises when amounts is empty" do
      expect do
        described_class.new(amounts: {}, effective_date: date, source_circular: "X")
      end.to raise_error(ArgumentError, /non-empty Hash/)
    end
  end
end
