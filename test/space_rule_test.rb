require_relative 'test_helper'
require "pegparse"
require "pegparse/basic_rules/space_rule"

class SpaceParser < Pegparse::Parser
  include Pegparse::BasicRules::SpaceRule

  def LINE_COMMENT()
    /#/
  end

  def BLOCK_COMMENT_BEGIN()
    /\/\*/
  end

  def BLOCK_COMMENT_END()
    /\*\//
  end

  def number()
    regexp(/[0-9]+/).to_i
  end
end

class RubyLikeCommentParser < Pegparse::Parser
  include Pegparse::BasicRules::SpaceRule

  def LINE_COMMENT()
    /#/
  end

  def BLOCK_COMMENT_BEGIN()
    /^=begin/
  end

  def BLOCK_COMMENT_END()
    /^=end/
  end

  def number()
    regexp(/[0-9]+/).to_i
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
    x = SpaceParser.new("1  2 \n 3")
    assert_equal 1, x.number()
    x.inline_sp()
    assert_equal 2, x.number()
    assert_throws(:failed){ x.inline_sp() }
  end

  def test_line_comment()
    x = SpaceParser.new("1#aaa\n2\n#aaa 3\n#aaa 4\n5")
    assert_equal 1, x.number()
    x.sp()
    assert_equal 2, x.number()
    x.sp()
    assert_equal 5, x.number()
  end

  def test_block_comment()
    x = SpaceParser.new("1 /*aaa*/ 2 /* / * / */ /* a\na\na */ 3")
    assert_equal 1, x.number()
    x.sp()
    assert_equal 2, x.number()
    x.sp()
    assert_equal 3, x.number()

    x = SpaceParser.new("1 /* /* aaa */ */ 2 ")
    assert_equal 1, x.number()
    x.sp()
    assert_equal 2, x.number()
  end

  def test_ruby_block_comment()
    x = RubyLikeCommentParser.new("1\n=begin\n2\n=end\n3")
    assert_equal 1, x.number()
    x.sp()
    assert_equal 3, x.number()

    x = RubyLikeCommentParser.new("1\n=begin\n2\n =end\n3\n=end\n4")
    assert_equal 1, x.number()
    x.sp()
    assert_equal 4, x.number()
  end

end
