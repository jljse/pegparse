require_relative '../lib/pegparse'

module Pegparse::Sample
end

class Pegparse::Sample::JsonParser < Pegparse::ParserBase
  class JsonNullNode
  end

  def initialize(context_or_scanner)
    super(context_or_scanner)
    self.start_rule_symbol = :start_rule
  end

  def start_rule
    sp()
    json_node()
  end

  rule def json_node
    choice(
      ->{ json_number_node() },
      ->{ json_string_node() },
      ->{ json_null_node() },
      ->{ json_bool_node() },
      ->{ json_object_node() },
      ->{ json_array_node() },
    )
  end

  def json_number_node
    str = read(/[0-9]+(\.[0-9]+)?/)
    str.to_f
  end

  rule def json_string_node
    read('"')
    ret = string_like('"', /[^"\\]*/){
      read("\\")
      read(/./m)
    }
    read('"')
    ret[0]
  end

  def json_null_node
    read('null')
    JsonNullNode.new
  end

  def json_bool_node
    choice(
      ->{
        read('true')
        true
      },
      ->{
        read('false')
        false
      },
    )
  end

  rule def json_object_node
    read('{')
    sp()
    pairs = separative(',') {
      key = json_object_key()
      sp()
      read(':')
      sp()
      val = json_node()
      [key, val]
    }
    sp()
    read('}')
    pairs.to_h
  end

  def json_object_key
    json_string_node()
  end

  rule def json_array_node
    read('[')
    sp()
    elements = separative(',') { json_node() }
    sp()
    read(']')
    elements
  end
end
