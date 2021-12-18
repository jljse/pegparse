# frozen_string_literal: true

require "test_helper"
require_relative "../samples/bsh_parser"
require 'strscan'

class SampleBshParserTest < Minitest::Test
  def test_initialize
    Pegparse::Sample::BshParser.new(nil)
  end

  def test_simple
    parser = Pegparse::Sample::BshParser.new(nil)
    ret = parser.parse(StringScanner.new('echo hello world'))
    assert_equal [[:command, [], [], 'echo', 'hello', 'world']], ret
  end

  def test_pipe
    parser = Pegparse::Sample::BshParser.new(nil)
    ret = parser.parse(StringScanner.new('cd somewhere && ls -a | head -n3'))
    assert_equal [
      ['&&',
        [:command, [], [], 'cd', 'somewhere'],
        ['|', 
          [:command, [], [], 'ls', '-a'],
          [:command, [], [], 'head', '-n3']]]
    ], ret
  end

  def test_concat
    parser = Pegparse::Sample::BshParser.new(nil)
    ret = parser.parse(StringScanner.new("ls '-'a"))
    assert_equal [
      [:command, [], [], 'ls', [:concat, '-', 'a']],
    ], ret
  end

  def test_sample
    data = File.read(Pathname(__dir__) + 'data' + 'profile.sh')
    parser = Pegparse::Sample::BshParser.new(StringScanner.new(data))
    ret = parser.parse
    # pp ret
    # p parser.best_errors
    assert ret
    assert ret[0]
    assert_equal :if, ret[0][0]
    assert_equal [:command, [], [], '[', [:dquote, [:var, 'PS1', ['-', '']], ], ']'], ret[0][1][0]
    assert_equal :if, ret[1][0]
  end

end
