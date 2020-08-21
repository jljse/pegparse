
module Pegparse
module BasicRules
  
  class HeredocMemoEntry
    # <<EOS position.
    attr_accessor :pos
    # Whether this matcher processed lf callback and stored result already.
    attr_accessor :is_processed
    # Cached result value.
    attr_accessor :value

    def initialize(pos, content_matcher, content_setter)
      @value = nil
      @pos = pos
      @is_processed = false
      @content_matcher = content_matcher
      @content_setter = content_setter
    end

    def update(content_matcher, content_setter)
      @content_matcher = content_matcher
      @content_setter = content_setter
    end

    def process_content()
      if @is_processed
        if @value == nil
          failed()
        else
          @content_setter.call(@value)
        end
      else
        @is_processed = true
        @value = nil
        content = @content_matcher.call()
        @value = content
        @content_setter.call(content)
      end
      nil
    end
  end

  class HeredocMemo
    def initialize
      # all memo (<<EOS pos => memo)
      @memo = {}
      # memo which not processed yet. (order by pos)
      @waiting_memo = []
    end

    def has_memo?(pos)
      @memo.key?(pos)
    end

    def is_processed_memo?(pos)
      @memo.key?(pos) and @memo[pos].is_processed
    end

    def get_memo(pos)
      @memo[pos]
    end

    def register(pos, content_matcher, content_setter)
      # puts "register #{pos}"

      if has_memo?(pos)
        oldmemo = @memo[pos]
        oldmemo.update(content_matcher, content_setter)
        return
      end

      # this is first time.
      newmemo = HeredocMemoEntry.new(pos, content_matcher, content_setter)
      @memo[pos] = newmemo

      # add to waiting_memo, keep in order of pos.
      insert_index = @waiting_memo.bsearch_index{|x| x.pos >= pos}
      if insert_index
        if @waiting_memo[insert_index].pos == pos
          # already registered, just skip.
        else
          @waiting_memo.insert(insert_index, newmemo)
        end
      else
        # no latter element, so just add to tail
        @waiting_memo << newmemo
      end
    end

    def dispatch_live_lf(pos)
      # puts "dispatch_live_lf #{pos}"

      if @waiting_memo.empty?
        return
      end
      # waiting_memo is orderd by pos, and only first heredoc has chance.
      if @waiting_memo.first.pos >= pos
        return
      end

      handler = @waiting_memo.shift
      handler.process_content()
      nil
    end
  end

  # Here-document rule (include this module into your parser class if needed)
  # This module requires SpaceRule. Please include it first.
  module HeredocRule
    extend Pegparse::WrapModule

    def initialize(text)
      super(text)
      @heredoc_memo = HeredocMemo.new
    end

    # override SpaceRule lf behavior to handle heredoc
    def space_rule_live_lf_callback()
      @heredoc_memo.dispatch_live_lf(current_pos())
      nil
    end

    # Heredoc-like syntax handling helper.
    # Content of heredoc is located in the "next line" of current position.
    #       This helper detect "next line" when "\n" is skipped by SpaceRule.any_space_or_comment.
    #
    #     RESTRICTION:
    #        | x <<y |  In ruby, heredoc parsing depends on sematics. (e.g. x and y definition)
    #        |  p 0  |  It could be heredoc and next line becomes heredoc-content,
    #        | y     |  could be shift-operator and next line becomes normal expression.
    #
    #       Pegparse cannot treat such ambiguity.
    #       Once you call handle_heredoc, next line will always be parsed as heredoc content,
    #         and never parse it again as other syntax even backtrack happen.
    #       
    #   content_match_proc : matching here-doc content. you have to consume text including end symbol.
    #                        result value will always be cached, so called only 1 time.
    #   content_setter_proc : {|content_match_proc's result value| save it to anywhere you like. }
    #                         after 2nd call of handle_heredoc, content always comes from cache.
    def handle_heredoc(content_match_proc, content_setter_proc)
      pos = current_pos()

      # always call register to replace procs,
      # because procs is bound for the specific closure.
      @heredoc_memo.register(pos, content_match_proc, content_setter_proc)

      if @heredoc_memo.is_processed_memo?(pos)
        memo = @heredoc_memo.get_memo(pos)
        memo.process_content()
      end

      # it's good if this could return valueable, but can't.
      nil
    end

  end
end
end
