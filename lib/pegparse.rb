# frozen_string_literal: true

require_relative "pegparse/version"
require_relative "pegparse/parser_base"
require_relative "pegparse/biop_rule_chain"

module Pegparse
  class Error < StandardError; end
end
