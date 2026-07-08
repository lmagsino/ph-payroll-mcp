# frozen_string_literal: true

require_relative "base_tool"

module Tools
  class ComputePagibigContribution < BaseTool
    tool_name "compute_pagibig_contribution"
    description "Compute the current Pag-IBIG (HDMF) monthly contribution (employee and " \
                "employer share) for a Philippine monthly salary. Returns the amounts with " \
                "the effective date and source circular."

    arguments do
      required(:monthly_salary).filled.description("Monthly salary in PHP (number)")
    end

    def call(monthly_salary:)
      domain { Payroll::PagibigCalculator.new.call(monthly_salary: monthly_salary).to_h }
    end
  end
end
