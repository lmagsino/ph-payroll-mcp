# frozen_string_literal: true

# Loads the payroll domain layer. Require this once (config.ru at boot, spec_helper
# in tests) to pull in errors, value objects, the rate-table registry, and the
# calculator base.
require_relative "payroll/errors"
require_relative "payroll/result"
require_relative "payroll/table"
require_relative "payroll/table_schema"
require_relative "payroll/rate_tables"
require_relative "payroll/base_calculator"
require_relative "payroll/philhealth_calculator"
require_relative "payroll/pagibig_calculator"
