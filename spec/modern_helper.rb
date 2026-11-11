# Run the existing library specs without the legacy Aruba CLI harness.
require "bundler/setup"
require "logger"
require "rspec"
require "figaro"
require_relative "support/reset"
