# frozen_string_literal: true

require "test_helper"

class LineCounterTest < Minitest::Test
  def test_initialize
    Pegparse::LineCounter.new
  end

  def test_memo
    counter = Pegparse::LineCounter.new

    #                0123 456789 01234567 89012345
    counter.memo(0, "abc\n  def\n")
    counter.memo(7,         "ef\n    ghi\n      jk")

    assert_equal([0, 0], counter.position(0))
    assert_equal(0, counter.indent(0))

    assert_equal([0, 3], counter.position(3))
    assert_equal([1, 0], counter.position(4))
    assert_equal(2, counter.indent(4))

    assert_equal([2, 5], counter.position(15))
    assert_equal(4, counter.indent(15))
    assert_equal(6, counter.indent(25))
  end
end
