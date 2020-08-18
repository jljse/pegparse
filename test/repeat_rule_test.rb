require_relative 'test_helper'
require "pegparse"
require "pegparse/basic_rules/repeat_rule"

class RepeatParser < Pegparse::Parser
  include Pegparse::BasicRules::RepeatRule

  def arg()
    regexp(/[a-z]/)
  end

  def sp?()
    regexp(/\s*/)
  end

  def array_literal_strict()
    str('[')
    sp?()
    elements = repeat_separator(proc{ arg() }, proc{ sp?() }, proc{ str(',') }, is_last_sep_allowed: false)
    sp?()
    str(']')
    elements
  end

  def array_literal_lax()
    str('[')
    sp?()
    elements = repeat_separator(proc{ arg() }, proc{ sp?() }, proc{ str(',') })
    sp?()
    str(']')
    elements
  end
end

class PegparseRepeatTest < Minitest::Test
  def test_strict
    x = RepeatParser.new('[a,b ,c]')
    assert_equal ['a', 'b', 'c'], x.array_literal_strict

    x = RepeatParser.new('[]')
    assert_equal [], x.array_literal_strict

    x = RepeatParser.new('[a,b,c,]')
    assert_throws(:failed){ x.array_literal_strict }
  end

  def test_lax
    x = RepeatParser.new('[ a , b , c ]')
    assert_equal ['a', 'b', 'c'], x.array_literal_lax

    x = RepeatParser.new('[]')
    assert_equal [], x.array_literal_lax

    x = RepeatParser.new('[a,b,c,]')
    assert_equal ['a', 'b', 'c'], x.array_literal_lax
  end

end