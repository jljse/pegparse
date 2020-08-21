require_relative 'test_helper'
require "pegparse"
require "pegparse/basic_rules/string_rule"

class StringParser < Pegparse::Parser
  include Pegparse::BasicRules::StringRule

  def string_literal_basic
    string_like_literal(/"/, /"/, ['"'])
  end

  def string_literal_escape
    string_like_literal(/"/, /"/, ['"', '\\']) do
      bt_branch(
        proc{ str('\\n'); "\n" },
        proc{ str('\\t'); "\t" },
        proc{ str('\\"'); '"' },
      )
    end
  end

  def string_literal_embedded
    string_like_literal(/"/, /"/, ['"', '\\', '$']) do
      bt_branch(
        proc{ str('\\$'); '$' },
        proc{
          str('$')
          sym = regexp(/[a-z]+/)
          sym.to_sym
        },
      )
    end
  end

  def string_literal_recursive
    string_like_literal(/"/, /"/, ['"', '\\', '#{']) do
      bt_branch(
        proc{ str('\\#'); '#' },
        proc{
          str('#{')
          inner = string_literal_recursive()
          str('}')
          inner
        },
      )
    end
  end

end

class PegparseStringTest < Minitest::Test
  def test_basic_string
    x = StringParser.new('"12345"')
    assert_equal ['12345'], x.string_literal_basic()

    x = StringParser.new('"12\n34\t5\"6"')
    assert_equal ['12\n34\t5\\'], x.string_literal_basic()
  end

  def test_escape_string
    x = StringParser.new('"12\n34\t5\"6"')
    assert_equal ["12\n34\t5\"6"], x.string_literal_escape()
  end

  def test_embedded
    x = StringParser.new('"12\$a34$x5"')
    assert_equal ['12$a34', :x, '5'], x.string_literal_embedded()
  end

  def test_recursive
    x = StringParser.new('"12\#a34#{"56#{"78"}90"}x"')
    assert_equal ['12#a34', ['56', ['78'], '90'], 'x'], x.string_literal_recursive()
  end
end
