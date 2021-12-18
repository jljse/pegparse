require_relative '../lib/pegparse'

module Pegparse::Sample
end

class Pegparse::Sample::XmlParser < Pegparse::ParserBase
  XmlNode = Struct.new(
    :tag, :attrs, :inner_nodes,
    keyword_init: true,
  )

  XmlAttr = Struct.new(
    :name, :value,
    keyword_init: true,
  )

  def initialize(context_or_scanner)
    super(context_or_scanner)
    self.start_rule_symbol = :start_rule
  end

  def line_comment
    backtrack
  end

  rule def block_comment
    read('<!--')
    read(/.*?-->/m)
  end

  def start_rule
    sp()
    decl = optional{ doc_declaration() }
    nodes = xml_nodes()
    [decl, nodes]
  end

  def intag_sp!
    read(/\s+/)
  end

  def intag_sp
    read(/\s*/)
  end

  def doc_declaration
    choice(
      ->{ xml_declaration() },
      ->{ html_declaration() },
    )
  end

  rule def xml_declaration
    read('<?xml')
    attrs = xml_attributes()
    intag_sp()
    read('>')
    attrs
  end

  rule def html_declaration
    read(/<!doctype html>/i)
  end

  def xml_attributes
    attrs = zero_or_more {
      intag_sp!()
      xml_attribute_pair()
    }
    attrs
  end

  def xml_attribute_pair
    name = xml_attribute_name()
    read('=')
    val = xml_attribute_value()
    XmlAttr.new(name: name, value: val)
  end

  rule def xml_attribute_name
    read(/[A-Za-z][A-Za-z0-9\-]*/)
  end

  rule def xml_tag_name
    read(/[A-Za-z][A-Za-z0-9\-]*/)
  end

  rule def xml_attribute_value
    choice(
      ->{ single_quote_string() },
      ->{ double_quote_string() },
    )
  end

  def single_quote_string
    ret = ''
    read("'")
    while true
      ret << read(/[^'\\]*/)
      break if peek("'")
      ret << read(/./)
    end
    read("'")
    ret
  end

  def double_quote_string
    ret = ''
    read('"')
    while true
      ret << read(/[^"\\]*/)
      break if peek('"')
      ret << read(/./)
    end
    read('"')
    ret
  end

  rule def xml_open_tag
    read('<')
    name = xml_tag_name()
    attrs = xml_attributes()
    intag_sp()
    read('>')
    [name, attrs]
  end

  rule def xml_close_tag
    read('</')
    intag_sp()
    name = xml_tag_name()
    intag_sp()
    read('>')
    name
  end

  rule def xml_empty_element_tag
    read('<')
    name = xml_tag_name()
    attrs = xml_attributes()
    intag_sp()
    read('/>')
    [name, attrs]
  end

  SPECIAL_NONEST_TAG = %w(meta br)
  rule def html_special_empty_element_tag
    read('<')
    name = xml_tag_name()
    backtrack() unless SPECIAL_NONEST_TAG.include?(name)
    attrs = xml_attributes()
    intag_sp()
    read(/\/?>/)
    [name, attrs]
  end

  def xml_node
    choice(
      ->{
        block_comment()
      },
      ->{
        text = read(/[^<]+/)
        text
      },
      ->{
        tag = xml_empty_element_tag()
        XmlNode.new(tag: tag[0], attrs: tag[1], inner_nodes: nil)
      },
      ->{
        tag = html_special_empty_element_tag()
        XmlNode.new(tag: tag[0], attrs: tag[1], inner_nodes: nil)
      },
      ->{
        opentag = xml_open_tag()
        inner = xml_nodes()
        closetag = xml_close_tag()
        backtrack if opentag[0] != closetag
        XmlNode.new(tag: opentag[0], attrs: opentag[1], inner_nodes: inner)
      }
    )
  end

  def xml_nodes
    nodes = zero_or_more {
      xml_node()
    }
    nodes
  end
end
