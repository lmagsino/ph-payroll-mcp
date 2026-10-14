# frozen_string_literal: true

require "date"

# Against the shipped 2026 calendar (Proclamations 1006, 1189, 1264). Combination
# rules (doubles, regular over special) use a stubbed table, since 2026 has no doubles.
RSpec.describe PhPayroll::HolidayCalendar do
  describe ".day" do
    it "types a regular holiday and names it" do
      day = described_class.day(Date.new(2026, 4, 9))
      expect(day.day_type).to eq("regular_holiday")
      expect(day.names).to eq(["Araw ng Kagitingan"])
      expect(day.sources).to eq(["Proclamation No. 1006"])
    end

    it "carries the separate Eid proclamation for Eid'l Fitr" do
      expect(described_class.day("2026-03-20").sources).to eq(["Proclamation No. 1189"])
    end

    it "types the special non-working and special working days" do
      expect(described_class.day("2026-08-21").day_type).to eq("special_non_working")
      expect(described_class.day("2026-02-25").day_type).to eq("special_working")
    end

    it "calls an unlisted date ordinary" do
      day = described_class.day("2026-04-08")
      expect(day.day_type).to eq("ordinary")
      expect(day.names).to be_empty
    end

    it "refuses a year with no calendar instead of reusing the latest one" do
      expect { described_class.day("2027-01-01") }
        .to raise_error(PhPayroll::RateTables::MissingRateTable, /no 2027 holiday calendar/)
    end

    it "refuses a year before any calendar" do
      expect { described_class.day("2025-12-25") }.to raise_error(PhPayroll::RateTables::MissingRateTable)
    end

    it "rejects a malformed date" do
      expect { described_class.day("2026-13-01") }.to raise_error(PhPayroll::InvalidInput)
    end
  end

  describe ".year" do
    it "lists every 2026 date in order" do
      days = described_class.year(2026)
      expect(days.length).to eq(21)
      expect(days.first.names).to eq(["New Year's Day"])
      expect(days.map(&:date)).to eq(days.map(&:date).sort)
      expect(days.count { |d| d.day_type == "regular_holiday" }).to eq(12)
    end
  end

  describe "dates shared by two holidays" do
    def stub_calendar(*entries)
      table = PhPayroll::Table.new(agency: "holidays", effective_date: Date.new(2030, 1, 1),
                                   source_circular: "TEST", data: { "year" => "2030", "dates" => entries })
      allow(PhPayroll::RateTables).to receive(:for).with("holidays", as_of: Date.new(2030, 12, 31)).and_return(table)
    end

    def entry(type, name) = { "date" => "2030-04-18", "name" => name, "type" => type }

    it "makes two regular holidays a double holiday" do
      stub_calendar(entry("regular_holiday", "A"), entry("regular_holiday", "B"))
      expect(described_class.day("2030-04-18").day_type).to eq("double_holiday")
    end

    it "makes two special days a double special day" do
      stub_calendar(entry("special_non_working", "A"), entry("special_non_working", "B"))
      expect(described_class.day("2030-04-18").day_type).to eq("double_special_non_working")
    end

    it "lets a regular holiday outrank a special day on the same date" do
      stub_calendar(entry("special_non_working", "A"), entry("regular_holiday", "B"))
      day = described_class.day("2030-04-18")
      expect(day.day_type).to eq("regular_holiday")
      expect(day.names).to contain_exactly("A", "B")
    end
  end
end
