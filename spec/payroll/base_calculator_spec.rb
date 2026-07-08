# frozen_string_literal: true

require "bigdecimal"
require "date"

RSpec.describe Payroll::BaseCalculator do
  # Concrete subclass for exercising the base mechanics.
  let(:calculator_class) do
    Class.new(described_class) do
      agency "philhealth"

      private

      def validate!(monthly_salary:)
        validate_positive_finite!(monthly_salary, field: "monthly_salary")
      end

      def compute(table, monthly_salary:)
        premium = round_centavo(clamp(monthly_salary, floor: table.decimal("floor"), ceiling: table.decimal("ceiling")) * table.decimal("rate"))
        { premium: premium }
      end
    end
  end

  let(:calc) { calculator_class.new }
  let(:table) do
    Payroll::Table.new(
      agency: "philhealth", effective_date: Date.new(2026, 1, 1),
      source_circular: "TEST 2026", data: { "rate" => "0.05", "floor" => "10000", "ceiling" => "100000" }
    )
  end

  describe "#call" do
    before { allow(Payroll::RateTables).to receive(:for).with("philhealth", as_of: kind_of(Date)).and_return(table) }

    it "returns a Result stamped with the table's citation" do
      result = calc.call(monthly_salary: 30_000)

      expect(result).to be_a(Payroll::Result)
      expect(result.source_circular).to eq("TEST 2026")
      expect(result.effective_date).to eq(Date.new(2026, 1, 1))
      expect(result.amounts[:premium]).to eq(BigDecimal("1500.00")) # 30_000 * 0.05
    end

    it "clamps the ceiling before computing (150k salary -> 100k base)" do
      expect(calc.call(monthly_salary: 150_000).amounts[:premium]).to eq(BigDecimal("5000.00")) # 100_000 * 0.05
    end

    it "rejects invalid input before computing" do
      expect { calc.call(monthly_salary: -5000) }.to raise_error(Payroll::InvalidInput, /greater than zero/)
    end
  end

  describe "an unimplemented subclass" do
    it "raises NotImplementedError from #compute" do
      bare = Class.new(described_class) { agency "sss" }.new
      allow(Payroll::RateTables).to receive(:for).and_return(table)
      expect { bare.call }.to raise_error(NotImplementedError, /must implement #compute/)
    end
  end

  describe "helpers" do
    describe "#bd" do
      it "coerces integers and numeric strings" do
        expect(calc.send(:bd, 5000)).to eq(BigDecimal("5000"))
        expect(calc.send(:bd, "1234.56")).to eq(BigDecimal("1234.56"))
      end

      it "raises on non-numeric string, nil, and non-finite float" do
        expect { calc.send(:bd, "abc") }.to raise_error(Payroll::InvalidInput)
        expect { calc.send(:bd, nil) }.to raise_error(Payroll::InvalidInput)
        expect { calc.send(:bd, Float::INFINITY) }.to raise_error(Payroll::InvalidInput)
        expect { calc.send(:bd, (0.0 / 0.0)) }.to raise_error(Payroll::InvalidInput)
      end
    end

    describe "#round_centavo" do
      it "rounds HALF_UP to 2 decimals" do
        expect(calc.send(:round_centavo, BigDecimal("1.005"))).to eq(BigDecimal("1.01"))
      end
    end

    describe "#clamp" do
      it "bounds below floor and above ceiling, passes through in range" do
        expect(calc.send(:clamp, 4000, floor: 5000, ceiling: 35_000)).to eq(BigDecimal("5000"))
        expect(calc.send(:clamp, 40_000, floor: 5000, ceiling: 35_000)).to eq(BigDecimal("35000"))
        expect(calc.send(:clamp, 20_000, floor: 5000, ceiling: 35_000)).to eq(BigDecimal("20000"))
      end

      it "raises when floor exceeds ceiling (misconfigured table)" do
        expect { calc.send(:clamp, 100, floor: 500, ceiling: 100) }.to raise_error(Payroll::InvalidInput, /floor .* exceeds ceiling/)
      end
    end

    describe "#validate_positive_finite!" do
      it "raises on zero and negative" do
        expect { calc.send(:validate_positive_finite!, 0, field: "x") }.to raise_error(Payroll::InvalidInput)
        expect { calc.send(:validate_positive_finite!, -1, field: "x") }.to raise_error(Payroll::InvalidInput)
      end
    end
  end
end
