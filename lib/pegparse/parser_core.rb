require_relative "parser_context"

# Parser base class (core mechanism for backtracking)
class Pegparse::ParserCore
  # start rule symbol used by parse()
  # @return [Symbol]
  attr_accessor :start_rule_symbol

  # @param scanner_or_context [StringScanner,Pegparse::ParserContext]
  def initialize(scanner_or_context)
    init_context(scanner_or_context) if scanner_or_context
  end

  # initialize inner state
  def init_context(scanner_or_context)
    if scanner_or_context.is_a? Pegparse::ParserContext
      @context = scanner_or_context
    else
      @context = Pegparse::ParserContext.new(scanner_or_context)
    end
  end

  # Start parse
  # @param scanner_or_context [StringScanner,Pegparse::ParserContext]
  # @param rule [Symbol]
  # @return [Object]  match result
  def parse(scanner_or_context = nil, rule: nil)
    raise ArgumentError if !scanner_or_context && !@context
    raise ArgumentError if !rule && !@start_rule_symbol

    init_context(scanner_or_context) if scanner_or_context
    current_start_rule_symbol = rule || @start_rule_symbol

    ret = nil
    catch(:backtrack) do
      ret = __send__(current_start_rule_symbol)
    end
    @context.errors.clear_errors if eos?
    return ret
  end

  def eos?
    @context.scanner.eos?
  end

  def save_error(reason)
    @context.errors.save_error(@context.scanner.pos, @context.rule_stack, reason)
  end

  def backtrack_position_to(pos)
    @context.scanner.pos = pos
    @context.borrowed_areas.backtracked(pos)
  end

  # parse error info
  # @return [Array]  array of meaningful errors. an element should be [[[line, char], parent reason], [[line, char], child reason]]
  def best_errors
    @context.errors.best_errors.map{|error|
      error.map{|rule|
        [ @context.line_counter.position(rule.pos), rule.reason ]
      }
    }
  end

  # Check whether matching will success or not.
  # @param str_or_regexp [String, Regexp, nil] matching (if nil, block will be used)
  # @return [String, Object] match result String (if you call with block, return is block's result)
  def peek(str_or_regexp = nil, &block)
    raise ArgumentError if str_or_regexp && block
    raise ArgumentError if !str_or_regexp && !block

    if block
      bk_pos = @context.scanner.pos
      ret = nil
      catch(:backtrack) do
        ret = block.call()
      end
      backtrack_position_to(bk_pos)
      return ret
    end

    if str_or_regexp.is_a?(String)
      if @context.scanner.match?(str_or_regexp)
        @context.line_counter.memo(@context.scanner.pos, str_or_regexp)
        if @context.borrowed_areas.conflicted_area(@context.scanner.pos + str_or_regexp.bytesize - 1)
          return nil
        end
        return str_or_regexp
      else
        return nil
      end
    end
    if str_or_regexp.is_a?(Regexp)
      if (size = @context.scanner.match?(str_or_regexp))
        str = @context.scanner.peek(size)
        @context.line_counter.memo(@context.scanner.pos, str)
        if @context.borrowed_areas.conflicted_area(@context.scanner.pos + size - 1)
          return nil
        end
        return str
      end
      return nil
    end
    raise ArgumentError
  end

  # Match with pattern. Backtrack if match failed.
  # @param str_or_regexp [String, Regexp] matching
  # @return [String] match result
  def read(str_or_regexp)
    raise ArgumentError unless str_or_regexp
    ret = peek(str_or_regexp)
    if ret
      @context.scanner.pos += ret.bytesize
      return ret
    end
    save_error(str_or_regexp)
    backtrack()
  end

  # Match with pattern or block. Returns nil if match failed.
  # @param str_or_regexp [String, Regexp, nil] matching (if nil, block will be used)
  # @return [String, Object] match result
  def optional(str_or_regexp = nil, &block)
    raise ArgumentError if str_or_regexp && block
    raise ArgumentError if !str_or_regexp && !block

    if block
      bk_pos = @context.scanner.pos
      ret = nil
      catch(:backtrack) do
        @context.rule_stack.push [@context.scanner.pos, :optional]
        ret = block.call()
        return ret
      ensure
        @context.rule_stack.pop
      end
      backtrack_position_to(bk_pos)
      return nil
    end

    ret = peek(str_or_regexp)
    @context.scanner.pos += ret.bytesize if ret
    return ret
  end

  def backtrack()
    throw :backtrack
  end

  def self.wrap_with_trace_method(method_sym)
    original_method_sym = ('original_' + method_sym.to_s).to_sym
    unless self.method_defined?(original_method_sym)
      self.alias_method original_method_sym, method_sym
      self.define_method(method_sym) do |*args|
        @context.rule_stack.push [@context.scanner.pos, method_sym]
        ret = self.__send__(original_method_sym, *args)
        return ret
      ensure
        @context.rule_stack.pop
      end
    end
  end

  # Wrap method as nonterminal symbol rule.
  # @param method_sym [Symbol] wrapping method symbol
  # @return [Symbol]
  def self.rule(method_sym)
    self.wrap_with_trace_method(method_sym)
    method_sym
  end

  ###

  # Try to match some candidates in order. (PEG's choice operator) Backtrack if all match failed.
  # @param alter_procs [Array<Proc>] match candidates
  # @return [Object] result of the matched candidate
  def choice(*alter_procs)
    alter_procs.each do |alter_proc|
      ret = optional{ alter_proc.call() }
      return ret if ret
    end
    backtrack()
  end

  # Try to match in loop. Returns [] even no loop succeeded.
  # @return [Array<Object>] array of match results for each loop
  def zero_or_more(&block)
    ret = []
    while true
      val = optional { block.call() }
      break unless val
      ret << val
    end
    return ret
  end

  # Try to match in loop. Backtrack if no loop succeeded.
  # @return [Array<Object>] array of match results for each loop
  def one_or_more(&block)
    ret = [block.call()]
    while true
      val = optional { block.call() }
      break unless val
      ret << val
    end
    return ret
  end

  # Temporarily change scanner position to next line(use for here-document)
  # area consumed by block becomes non-matchable().
  def borrow_next_line(&block)
    mark_pos = @context.scanner.pos
    if @context.borrowed_areas.borrowed_area_end_pos
      borrowed_start_pos = @context.borrowed_areas.borrowed_area_end_pos
    else
      read(/.*\n/)
      borrowed_start_pos = @context.scanner.pos
    end
    @context.scanner.pos = borrowed_start_pos
    ret = block.call
    borrowed_end_pos = @context.scanner.pos
    @context.scanner.pos = mark_pos
    @context.borrowed_areas.add_area(Pegparse::BorrowedArea.new(
      marker_pos: mark_pos,
      start_pos: borrowed_start_pos,
      end_pos: borrowed_end_pos,
    ))
    return ret
  end

  # match to borrowed area
  def borrowed_area
    if area = @context.borrowed_areas.conflicted_area(@context.scanner.pos)
      if area.start_pos == @context.scanner.pos
        ret = @context.scanner.peek(area.end_pos - area.start_pos)
        @context.scanner.pos = area.end_pos
        return ret
      end
    end
    backtrack()
  end
end
