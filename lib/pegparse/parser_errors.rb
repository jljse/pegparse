
module Pegparse
  ParserError = Struct.new(
    :pos,
    :reason,
    keyword_init: true,
  )

  ParseErrorLocation = Struct.new(
    :index_in_errors,
    :start_positions_of_optional,
    keyword_init: true,
  )
end

class Pegparse::ParserErrors
  def initialize
    @farthest_pos = 0
    @farthest_errors = []
  end

  # just save parsing error
  # @params pos [Integer]
  # @params rule_stack [Array]  array of [matching start pos, matching symbol]
  # @params reason [Object]
  def save_error(pos, rule_stack, reason)
    return if pos < @farthest_pos
    if pos > @farthest_pos
      @farthest_errors.clear
    end
    @farthest_pos = pos
    copy_stack = rule_stack.map{|pos, reason| Pegparse::ParserError.new(pos: pos, reason: reason) }
    copy_stack << Pegparse::ParserError.new(pos: pos, reason: reason)
    @farthest_errors << copy_stack
  end

  # compare two errors which is better by parsing descent path
  #   (optional matching starts more earlier, priority becomes lower)
  # @params a [Pegparse::ParseErrorLocation]
  # @params b [Pegparse::ParseErrorLocation]
  def compare_optional_memo(a, b)
    a_opts = a.start_positions_of_optional
    b_opts = b.start_positions_of_optional

    for i in 0...[a_opts.size, b_opts.size].min
      if a_opts[i] > b_opts[i]
        return -1
      end
      if a_opts[i] < b_opts[i]
        return 1
      end
    end
    return a_opts.size <=> b_opts.size
  end

  # get meaningful errors
  # @return [Array<Pegparse::ParseError>]
  def best_errors
    optional_memos = @farthest_errors.map.with_index do |stack, index|
      Pegparse::ParseErrorLocation.new(
        index_in_errors: index,
        start_positions_of_optional: stack.select{|rule| rule.reason == :optional}.map{|rule| rule.pos}
      )
    end

    best_memos = []
    optional_memos.each do |memo|
      if best_memos.empty?
        best_memos << memo
        next
      end
      cmp = compare_optional_memo(memo, best_memos[0])
      if cmp < 0
        best_memos = [memo]
        next
      elsif cmp == 0
        best_memos << memo
        next
      else
        next
      end
    end

    bests = best_memos.map{|x| @farthest_errors[x.index_in_errors]}
    
    result = bests.map do |stack|
      stack.select{|x| x.reason != :optional}.last(2)
    end
    result
  end

  # remove all stored errors
  def clear_errors
    @farthest_pos = 0
    @farthest_errors = []
  end
end
