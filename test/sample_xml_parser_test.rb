# frozen_string_literal: true

require "test_helper"
require "pegparse/samples/xml_parser"
require 'strscan'

class SampleXmlParserTest < Minitest::Test
  def test_initialize
    Pegparse::Sample::XmlParser.new(nil)
  end

  def test_simple
    parser = Pegparse::Sample::XmlParser.new(nil)
    ret = parser.parse(StringScanner.new('<a></a>'))
    assert_nil ret[0]
    nodes = ret[1]
    assert_instance_of Pegparse::Sample::XmlParser::XmlNode, nodes[0]
    assert_equal 'a', nodes[0].tag
  end

  def test_nest
    parser = Pegparse::Sample::XmlParser.new(nil)
    ret = parser.parse(StringScanner.new('<a href="xxx" target="_blank">link is <b>here</b>.</a>'))
    assert_nil ret[0]
    nodes = ret[1]
    assert_instance_of Pegparse::Sample::XmlParser::XmlNode, nodes[0]
    a = nodes[0]
    assert_equal 'a', a.tag
    assert_equal 'href', a.attrs[0].name
    assert_equal 'xxx', a.attrs[0].value
    assert_equal 'target', a.attrs[1].name
    assert_equal '_blank', a.attrs[1].value
    assert_equal 3, a.inner_nodes.size
    assert_equal 'link is ', a.inner_nodes[0]
    assert_instance_of Pegparse::Sample::XmlParser::XmlNode, a.inner_nodes[1]
    assert_equal 'b', a.inner_nodes[1].tag
    assert_equal 'here', a.inner_nodes[1].inner_nodes[0]
    assert_equal '.', a.inner_nodes[2]
  end

  def test_google
    data = File.read(Pathname(__dir__) + 'data' + 'google.html')
    parser = Pegparse::Sample::XmlParser.new(StringScanner.new(data))
    ret = parser.parse
    assert ret[1]
    assert parser.eos?
  end

end
