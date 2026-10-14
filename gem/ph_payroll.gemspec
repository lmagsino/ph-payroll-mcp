# frozen_string_literal: true

require_relative "lib/ph_payroll/version"

Gem::Specification.new do |spec|
  spec.name = "ph_payroll"
  spec.version = PhPayroll::VERSION
  spec.authors = ["Leo Magsino"]
  spec.email = ["leo.magsino819@gmail.com"]

  spec.summary = "Philippine statutory payroll math (SSS, PhilHealth, Pag-IBIG, BIR), cited to its circulars"
  spec.description = "Computes Philippine SSS, PhilHealth and Pag-IBIG contributions, BIR monthly " \
                     "withholding tax, 13th-month pay and net pay from versioned rate tables. Every " \
                     "result carries the effective date and the agency circular it came from."
  spec.homepage = "https://github.com/lmagsino/ph-payroll-mcp/tree/main/gem"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["source_code_uri"] = "https://github.com/lmagsino/ph-payroll-mcp/tree/main/gem"
  spec.metadata["changelog_uri"] = "https://github.com/lmagsino/ph-payroll-mcp/blob/main/gem/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "data/**/*.yml", "README.md", "CHANGELOG.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "bigdecimal", ">= 3.1"
end
