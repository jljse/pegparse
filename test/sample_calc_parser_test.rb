# frozen_string_literal: true

require "test_helper"
require_relative "../samples/calc_parser"
require 'strscan'

class SampleCalcParserTest < Minitest::Test
  def test_initialize
    Pegparse::Sample::CalcParser.new(nil)
  end

  def test_simple
    parser = Pegparse::Sample::CalcParser.new(nil)
    ret = parser.parse(StringScanner.new('1+2'))
    assert_equal 3, ret
  end

  def test_nest
    parser = Pegparse::Sample::CalcParser.new(nil)
    ret = parser.parse(StringScanner.new('1+2*3+(4-(5+6))/7+8'))
    assert_equal 14, ret
  end

end
