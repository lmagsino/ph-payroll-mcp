# frozen_string_literal: true

# Philippine statutory payroll math. Requiring this loads the errors, value objects,
# the rate-table registry, and every calculator.
require_relative "ph_payroll/version"
require_relative "ph_payroll/errors"
require_relative "ph_payroll/result"
require_relative "ph_payroll/table"
require_relative "ph_payroll/table_schema"
require_relative "ph_payroll/rate_tables"
require_relative "ph_payroll/holiday_calendar"
require_relative "ph_payroll/base_calculator"
require_relative "ph_payroll/philhealth_calculator"
require_relative "ph_payroll/pagibig_calculator"
require_relative "ph_payroll/sss_calculator"
require_relative "ph_payroll/withholding_tax_calculator"
require_relative "ph_payroll/thirteenth_month_calculator"
require_relative "ph_payroll/net_pay_calculator"
