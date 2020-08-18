require "pegparse/version"
require 'strscan'

module Pegparse

  # Parsing error info
  class ErrorInfo
    attr_accessor :bytepos
    attr_accessor :expected

    def initialize()
      @bytepos = 0
      @expected = Set.new
    end

    # Update error info
    def save_failed(bytepos, expected)
      if bytepos == @bytepos
        @expected << expected if expected
        @bytepos = bytepos
      elsif bytepos > @bytepos
        @expected.clear
        @expected << expected if expected
        @bytepos = bytepos
      end
    end
  end

  # Debug info
  class DebugContext
    # Range of byte for debug trace enabled.
    attr_accessor :byterange
    attr_accessor :context
    
    def initialize(context)
      @context = context
      @byterange = (..-1)
      @is_firsttime = true
      @index_cache = [0]
    end

    def escape_for_debug(t)
      t2 = t.clone.force_encoding(Encoding::BINARY)
      t2.gsub!(/[^[:ascii:]]/){|x| "?" * x.bytesize }
      t2.gsub!("\n", "\\n")
      t2.gsub!("\t", "\\t")
      return t2
    end

    def escaped_width_for_debug(ch)
      if ch == "\n" or ch == "\t"
        return 2
      else
        return 1
      end
    end

    def start_bytepos
      @byterange.first
    end

    def escaped_index_for_debug(n)
      if start_bytepos + @index_cache.size <= n
        for i in start_bytepos+@index_cache.size .. n
          @index_cache[i - start_bytepos] =
            @index_cache[i - start_bytepos - 1] + escaped_width_for_debug(@context.text.byteslice(i - 1).force_encoding(Encoding::BINARY))
        end
      end

      return @index_cache[n - start_bytepos]
    end

    def indent(bytepos)
      return " " * escaped_index_for_debug(bytepos)
    end

    # Print parsing target text around specific position.
    def print_current_text(bytepos, name)
      if @byterange.cover?(bytepos)
        puts escape_for_debug(@context.text.byteslice(@byterange))
      end
    end

    # Print parsing event.
    def print_message(bytepos, name, message)
      if @byterange.cover?(bytepos)
        puts indent(bytepos) + name.to_s + " " + message
      end
    end

    # Print debug info on enter rule.
    def debug_enter(pos, rule_text)
      print_current_text(pos, rule_text)
      print_message(pos, rule_text, "")
    end

    # Print debug info on rule successed.
    def debug_success(pos, rule_text)
      print_message(pos, rule_text, "SUCCESS")
    end

    # Print debug info on rule failed.
    def debug_failed(pos, rule_text)
      print_message(pos, rule_text, "FAILED")
    end

    # Print debug info on memo cached.
    def debug_memo_cached(pos, rule_text)
      print_message(pos, rule_text, "CACHED")
    end

    # Print debug info on memo hit.
    def debug_memo_cache_hit(pos, rule_text)
      print_message(pos, rule_text, "CACHEHIT")
    end

  end

  # PEG memoize info entry.
  class MemoEntry
    attr_accessor :consumed_text_size
    attr_accessor :value

    def initialize(consumed_text_size, value)
      @consumed_text_size = consumed_text_size
      @value = value
    end
  end

  # PEG memoize info.
  class MemoInfo
    def initialize()
      @memo = Hash.new{|h,k| h[k] = {}}
    end

    def has_memo?(pos, type)
      @memo.has_key?(pos) && @memo[pos].has_key?(type)
    end

    def get_memo(pos, type)
      if @memo.has_key?(pos)
        return @memo[pos][type]
      else
        return nil
      end
    end

    def set_memo(pos, type, value)
      @memo[pos][type] = value
    end

  end

  module WrapMethodHelper
    # Wrap and replace method.
    def self.wrap_method(klass, sym, wrap_body_sym)
      old_sym = nil
      new_sym = nil
      unless klass.method_defined?("wrap_#{sym}_0")
        original_sym = "original_#{sym}"
        klass.alias_method(original_sym, sym)
        old_sym = original_sym
        new_sym = "wrap_#{sym}_0"
      else
        new_wrap_number = 0
        while klass.method_defined?("wrap_#{sym}_#{new_wrap_number}")
          new_wrap_number += 1
        end
        new_sym = "wrap_#{sym}_#{new_wrap_number}"
        old_sym = "wrap_#{sym}_#{new_wrap_number - 1}"
      end
  
      klass.define_method(new_sym) do |*args|
        __send__(wrap_body_sym, sym, args) do
          __send__(old_sym, *args)
        end
      end
      klass.alias_method(sym, new_sym)
  
      return sym
    end
  end

  module WrapModule
    # Wrap method with debug trace.
    def trace(sym)
      WrapMethodHelper.wrap_method(self, sym, :trace_body)
    end
  
    # Wrap method with PEG memoize.
    # If use "memoize" "trace" together, you should write in order of "trace memoize".
    def memoize(sym)
      WrapMethodHelper.wrap_method(self, sym, :memoize_body)
    end
  end

  # Saved status to rollback context transaction.
  class ContextStatus
    attr_accessor :pos
  end

  # Parsing context.
  class Context
    attr_accessor :text
    attr_accessor :error_info
    attr_accessor :debug
    attr_accessor :scanner
  
    def initialize(text = nil)
      if text
        @text = text
        @memo = MemoInfo.new()
        @error_info = ErrorInfo.new()
        @debug = DebugContext.new(self)
        @scanner = StringScanner.new(text)
      end
    end
  
    # save status to make transaction.
    def get_context_status()
      ret = ContextStatus.new
      ret.pos = @scanner.pos
      return ret
    end
    
    # load status to rollback transaction.
    def set_context_status(stat)
      @scanner.pos = stat.pos
    end
  
    #-----------------------------
    # core text access
    #-----------------------------

    # Check whether current context matches to string.
    # If success, return x. If not, return nil.
    def peek_str?(x)
      size = @scanner.match?(x)
      if size
        return x
      else
        return nil
      end
    end

    # Check whether current context matches to regexp.
    # If success, return matched string. If not, return nil.
    def peek_regexp?(regexp)
      size = @scanner.match?(regexp)
      if size
        return @scanner.peek(size)
      else
        return nil
      end
    end
  
    # Check whether current context is on EOS.
    def peek_eos?
      @scanner.eos?
    end
  
    # Consume(move context forward) n-byte.
    def consume!(n)
      @scanner.pos += n
    end
  
    # Get n-byte string at current context.
    def current_text(n)
      @scanner.peek(n)
    end
  
    # Get current context position(in byte).
    def current_pos()
      @scanner.pos
    end
  
    #-----------------------------
    # backtrack mechanism
    #-----------------------------

    # Trigger backtrack.
    def failed(expected = nil)
      @error_info.save_failed(current_pos(), expected)
      throw :failed
    end
  
    # PEG operation "*" .
    # Returns array of block's result value.
    def bt_loop(&block)
      ret = []
      x = nil
      catch(:failed) do
        loop do
          x = self.get_context_status()
          val = block.call()
          ret << val
        end
      end
      self.set_context_status(x)
      return ret
    end
  
    # PEG operation "+" .
    # Returns array of block's result value.
    def bt_loop_requred(&block)
      ret = []
      ret << (block.call())
      x = nil
      catch(:failed) do
        loop do
          x = self.get_context_status()
          val = block.call()
          ret << val
        end
      end
      self.set_context_status(x)
      return ret
    end
  
    # PEG operation "/" .
    # Returns block's result value.
    def bt_branch(*branches)
      branches.each do |br|
        val = nil
        x = self.get_context_status()
        catch(:failed) do 
          val = br.call()
          return val
        end
        self.set_context_status(x)
      end
      failed()
    end
  
    # PEG operation "?" .
    # Returns block's result value or nil.
    def bt_maybe(&match)
      x = self.get_context_status()
      catch(:failed) do
        val = match.call()
        return val
      end
      self.set_context_status(x)
      return nil
    end
  
    # PEG operation "&" .
    # Returns block's result value.
    def bt_lookahead(&match)
      x = self.get_context_status()
      catch(:failed) do
        val = match.call()
        self.set_context_status(x)
        return val
      end
      failed()
    end
  
    # PEG operation "!" .
    def bt_lookahead_deny(&match)
      x = self.get_context_status()
      is_success = false
      catch(:failed) do
        match.call()
        is_success = true
      end
      if is_success
        failed()
      else
        self.set_context_status(x)
        return nil
      end
    end
  
    #-------------------------------------------
    # method wrapper body
    #-------------------------------------------
    extend WrapModule

    # Body of "trace". See WrapModule.
    def trace_body(sym, args, &body)
      if args && args.size > 0
        trace_text = "#{sym}(" + args.inspect + ")"
      else
        trace_text = "#{sym}"
      end
  
      is_success = false
      start_pos = current_pos()
      begin
        @debug.debug_enter(start_pos, trace_text)
        result = body.call()
        is_success = true
        return result
      ensure
        if is_success
          @debug.debug_success(start_pos, trace_text)
        else
          @debug.debug_failed(start_pos, trace_text)
        end
      end
    end
  
    # Body of "memoize". See WrapModule.
    def memoize_body(sym, args, &body)
      prev_pos = current_pos()
  
      if @memo.has_memo?(prev_pos, sym)
        @debug.debug_memo_cache_hit(prev_pos, sym)
        cached_memo_info = @memo.get_memo(prev_pos, sym)
        if cached_memo_info.value
          consume!(cached_memo_info.consumed_text_size)
          return cached_memo_info.value
        else
          # failure is cached
          # this failure is already cached, so no need to pass expectation
          failed()
        end
      else
        is_success = false
        begin
          result = body.call
          is_success = true
          return result
        ensure
          after_pos = current_pos()
          @debug.debug_memo_cached(prev_pos, sym)
          @memo.set_memo(prev_pos, sym, MemoEntry.new(after_pos - prev_pos, is_success ? result : nil))
        end
      end
    end
  
  end

  # Parser base class.
  class Parser < Context
    # Match to string
    def str_notrace(s)
      if peek_str?(s)
        consume!(s.bytesize)
        return s
      else
        failed(s)
      end
    end
    # Match to string
    trace def str(s)
      str_notrace(s)
    end

    # Match to regexp
    def regexp_notrace(pat)
      m = peek_regexp?(pat)
      if m
        # consume!(m[0].size)
        # return m[0]
        consume!(m.bytesize)
        return m
      else
        failed(pat)
      end
    end
    # Match to regexp
    trace def regexp(pat)
      regexp_notrace(pat)
    end
  end

end
