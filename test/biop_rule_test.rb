require_relative 'test_helper'
require "pegparse"
require 'pegparse/basic_rules/space_rule'
require 'pegparse/basic_rules/biop_rule'


class BiopParser < Pegparse::Parser
  include Pegparse::BasicRules::SpaceRule
  include Pegparse::BasicRules::BiopRule

  def number()
    regexp(/[0-9]+/).to_i
  end

  def mul()
    left_biop(['*', '/'], proc{ sp?() }, proc{ number() }, &proc{|op, l, r| [op, l, r] })
  end

  def add()
    left_biop(['+', '-'], proc{ sp?() }, proc{ mul() }){|op, l, r| [op, l, r] }
  end
end


class BiopParser2 < Pegparse::Parser
  include Pegparse::BasicRules::SpaceRule
  include Pegparse::BasicRules::BiopRule

  def number()
    regexp(/[0-9]+/).to_i
  end

  def mul()
    left_biop(['*', '/'], proc{ sp?() }, proc{ number() }) do |op, l, r|
      case op
      when "*"
        l * r
      when "/"
        l / r
      end
    end
  end

  def add()
    left_biop(['+', '-'], proc{ sp?() }, proc{ mul() }, &proc{|op, l, r|
        case op
        when "+"
          l + r
        when "-"
          l - r
        end
      }
    )
  end
end


class PegparseBiopTest < Minitest::Test
  def test_arith_mul
    x = BiopParser.new("1*2/3")
    assert_equal ['/', ['*', 1, 2], 3],  x.mul()

    x = BiopParser.new("1 *2/  3")
    assert_equal ['/', ['*', 1, 2], 3],  x.mul()

    x = BiopParser.new("1*2+3")
    assert_equal ['*', 1, 2],  x.mul()
    assert_equal 3, x.current_pos()
  end

  def test_arith_add
    x = BiopParser.new("1+2-3")
    assert_equal ['-', ['+', 1, 2], 3],  x.add()

    x = BiopParser.new("1*2+3")
    assert_equal ['+', ['*', 1, 2], 3],  x.add()

    x = BiopParser.new("1+2*3")
    assert_equal ['+', 1, ['*', 2, 3]],  x.add()
  end

  def test_result
    x = BiopParser2.new("1 + 2 * 3")
    assert_equal 7, x.add()

    x = BiopParser2.new("1+2*3/2-6/3")
    assert_equal 2, x.add()
  end

end

