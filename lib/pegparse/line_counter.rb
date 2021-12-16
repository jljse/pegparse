
# count line number and indent level
class Pegparse::LineCounter
  def initialize
    @line_start_pos = [0]
    @line_start_pos_noindent = [0]
    @farthest_pos = 0
  end

  # update with partial string
  # @param pos [Integer]  position of str relative to whole input
  # @param str [String]  partial string
  def memo(pos, str)
    return if pos + str.size < @farthest_pos
    raise ArgumentError if pos > @farthest_pos

    row, * = position(pos)
    str.each_byte.with_index do |ch, index|
      if ch == ' '.ord || ch == "\t".ord
        # 既知のインデントより後ろに空白が続いている場合、インデントの深さを増やす
        if (pos + index) == (@line_start_pos_noindent[row])
          @line_start_pos_noindent[row] += 1
        end
      end
      if ch == "\n".ord
        next_line_start_pos = pos + index + 1
        if @line_start_pos.last < next_line_start_pos
          @line_start_pos << next_line_start_pos
          @line_start_pos_noindent << next_line_start_pos
        end
        row += 1
      end
    end
    if @farthest_pos < pos + str.size
      @farthest_pos = pos + str.size
    end
  end

  # get line number and char offset for pos
  # @param pos [Integer]
  # @return [Array[Integer]]
  def position(pos)
    if pos >= @line_start_pos.last
      line_count = @line_start_pos.size - 1
    else
      after_pos_line_head = @line_start_pos.bsearch_index{|x| x > pos}
      line_count = after_pos_line_head - 1
    end
    char_count = pos - @line_start_pos[line_count]

    [line_count, char_count]
  end

  # get indent level for the line including pos
  # @param pos [Integer]
  # @return [Integer]
  def indent(pos)
    line_count, * = position(pos)
    @line_start_pos_noindent[line_count] - @line_start_pos[line_count]
  end
end
