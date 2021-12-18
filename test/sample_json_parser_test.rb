# frozen_string_literal: true

require "test_helper"
require_relative "../samples/json_parser"
require 'strscan'
require 'pathname'

class SampleJsonParserTest < Minitest::Test
  def test_initialize
    Pegparse::Sample::JsonParser.new(nil)
  end

  def test_simple
    parser = Pegparse::Sample::JsonParser.new(nil)
    ret = parser.parse(StringScanner.new('{}'))
    assert_equal Hash.new, ret
  end

  def test_nest
    parser = Pegparse::Sample::JsonParser.new(nil)
    ret = parser.parse(StringScanner.new('{"x": [1, 2], "y": {}}'))
    assert_equal ({ 'x' => [1, 2], 'y' => Hash.new }), ret
  end

  def test_sample
    data = File.read(Pathname(__dir__) + 'data' + 'sample.json')
    parser = Pegparse::Sample::JsonParser.new(StringScanner.new(data))
    ret = parser.parse
    assert ret
    assert_equal 'example glossary', ret['glossary']['title']
    assert_equal 'XML', ret['glossary']['GlossDiv']['GlossList']['GlossEntry']['GlossDef']['GlossSeeAlso'][1]
  end

end
