# frozen_string_literal: true

# Loads the domain layer + every MCP tool adapter, and exposes Tools::ALL for
# registration on the fast-mcp server (config.ru). Require this once.
require_relative "../payroll"
require_relative "tools/base_tool"
require_relative "tools/compute_sss_contribution"
require_relative "tools/compute_philhealth_contribution"
require_relative "tools/compute_pagibig_contribution"
require_relative "tools/compute_withholding_tax"
require_relative "tools/compute_13th_month_pay"
require_relative "tools/compute_net_pay"
require_relative "tools/get_contribution_table"

module Tools
  ALL = [
    ComputeSssContribution,
    ComputePhilhealthContribution,
    ComputePagibigContribution,
    ComputeWithholdingTax,
    Compute13thMonthPay,
    ComputeNetPay,
    GetContributionTable
  ].freeze
end
