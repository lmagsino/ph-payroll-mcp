# frozen_string_literal: true

# Loads the domain layer + every MCP tool adapter, and exposes Tools::ALL for
# registration on the MCP::Server (config.ru). Require this once.
require "ph_payroll"
require_relative "tools/base_tool"
require_relative "tools/compute_sss_contribution"
require_relative "tools/compute_philhealth_contribution"
require_relative "tools/compute_pagibig_contribution"
require_relative "tools/compute_withholding_tax"
require_relative "tools/compute_13th_month_pay"
require_relative "tools/compute_net_pay"
require_relative "tools/get_contribution_table"
require_relative "tools/compute_holiday_pay"
require_relative "tools/list_holidays"

module Tools
  ALL = [
    ComputeSssContribution,
    ComputePhilhealthContribution,
    ComputePagibigContribution,
    ComputeWithholdingTax,
    Compute13thMonthPay,
    ComputeNetPay,
    GetContributionTable,
    ComputeHolidayPay,
    ListHolidays
  ].freeze
end
