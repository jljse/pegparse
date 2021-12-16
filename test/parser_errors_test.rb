# frozen_string_literal: true

require "test_helper"

class ParserErrorsTest < Minitest::Test
  def test_initialize
    Pegparse::ParserErrors.new
  end

  def test_best_errors
    errors = Pegparse::ParserErrors.new
    errors.save_error(4, [[0, :all], [2, :optional], [2, :something]], :parse0)
    errors.save_error(5, [[0, :all], [2, :optional], [2, :something]], :parse1)
    errors.save_error(5, [[0, :all], [3, :optional], [3, :something]], :parse2)
    best = errors.best_errors.first
    assert_equal(3, best[0].pos)
    assert_equal(:something, best[0].reason)
    assert_equal(5, best[1].pos)
    assert_equal(:parse2, best[1].reason)
  end
end
