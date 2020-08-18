
module Pegparse
module BasicRules

  # Spaces and Comment rules (include this module into your parser class if needed)
  module SpaceRule
    extend Pegparse::WrapModule

    # One line comment start
    def LINE_COMMENT()
      # /#/
      nil
    end

    # Block comment start
    def BLOCK_COMMENT_BEGIN()
      # /\/\*/
      nil
    end

    # Block comment end
    def BLOCK_COMMENT_END()
      # /\*\//
      nil
    end

    # ------------------------------------
    # rules
    # ------------------------------------

    def comment()
      rules = []
      if LINE_COMMENT()
        rules << proc{ line_comment() }
      end
      if BLOCK_COMMENT_BEGIN()
        rules << proc{ block_comment() }
      end

      bt_branch(*rules)
    end

    def line_comment()
      begin_str = regexp_notrace(LINE_COMMENT())
      regexp_notrace(/.*\n/)
      return begin_str
    end

    def block_comment()
      begin_str = regexp_notrace(BLOCK_COMMENT_BEGIN())
      
      break_regexp = Regexp.union(BLOCK_COMMENT_BEGIN(), BLOCK_COMMENT_END())
      loop do
        # this is very special case to touch @scanner directly
        skipped = @scanner.check_until(break_regexp)
        unless skipped
          break
        end
        matched = @scanner.matched
        consume!(skipped.bytesize - matched.bytesize)

        if peek_regexp?(BLOCK_COMMENT_BEGIN())
          block_comment()
        elsif peek_regexp?(BLOCK_COMMENT_END())
          break
        else
          regexp(/./)
        end
      end
      
      end_str = regexp_notrace(BLOCK_COMMENT_END())
      return begin_str + end_str
    end

    memoize def any_space_or_comment()
      prev_pos = current_pos()
      bt_loop do
        bt_branch(
          proc{ comment() },
          proc{ regexp(/[ \t\r\n]+/) },
        )
      end
      after_pos = current_pos()

      # This is special process to return text before current position
      return self.text.byteslice(prev_pos ... after_pos)
    end

    # Spaces (must contain newline)
    trace def lf()
      spaces = any_space_or_comment()
      if spaces.include?("\n")
        return spaces
      else
        failed(:lf)
      end
    end

    # Spaces (without newline)
    trace def inline_sp()
      spaces = any_space_or_comment()
      if spaces.include?("\n")
        failed(:inline_sp)
      elsif spaces.size == 0
        failed(:inline_sp)
      else
        return spaces
      end
    end
    
    # Spaces (without newline, could be blank)
    def inline_sp?()
      spaces = any_space_or_comment()
      if spaces.include?("\n")
        failed(:inline_sp)
      else
        return spaces
      end
    end
    
    # Spaces (allow newline)
    trace def sp()
      spaces = any_space_or_comment()
      if spaces.size == 0
        failed(:sp)
      else
        return spaces
      end
    end
    
    # Spaces (allow newline, could be blank)
    def sp?()
      any_space_or_comment()
    end

  end
end
end