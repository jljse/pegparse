require_relative "parser_errors"
require_relative "line_counter"
require_relative "borrowed_areas"

class Pegparse::ParserContext
  attr_accessor :scanner
  attr_accessor :rule_stack
  attr_accessor :errors
  attr_accessor :line_counter
  attr_accessor :borrowed_areas

  def initialize(scanner)
    @scanner = scanner
    @rule_stack = []
    @errors = Pegparse::ParserErrors.new
    @line_counter = Pegparse::LineCounter.new
    @borrowed_areas = Pegparse::BorrowedAreas.new
  end
end
