require_relative 'test_helper'
require "pegparse"
require "pegparse/basic_rules/space_rule"

class SpaceParser < Pegparse::Parser
  include Pegparse::BasicRules::SpaceRule

  def number()
    s = regexp(/[0-9]+/)
    s.to_i
  end
end

class PegparseSpaceTest < Minitest::Test
  def test_sp()
    x = SpaceParser.new("1 2  3\n4\t5ab")
    assert_equal 1, x.number()
    x.sp()
    assert_equal 2, x.number()
    x.sp()
    assert_equal 3, x.number()
    x.sp()
    assert_equal 4, x.number()
    x.sp()
    assert_equal 5, x.number()
    assert_throws(:failed){ x.sp() }

    x = SpaceParser.new("1a 2\nb")
    assert_equal 1, x.number()
    x.sp?()
    assert_equal 'a', x.regexp(/[a-z]+/)
    x.sp?()
    assert_equal 2, x.number()
    x.sp?()
    assert_equal 'b', x.regexp(/[a-z]+/)
  end

  def test_lf()
    x = SpaceParser.new("1 \n 2  3")
    assert_equal 1, x.number()
    x.lf()
    assert_equal 2, x.number()
    assert_throws(:failed){ x.lf() }
  end

  def test_inline_sp()
  end

  def test_comment()
  end

end
