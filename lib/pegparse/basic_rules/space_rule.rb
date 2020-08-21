
module Pegparse
module BasicRules

  # memo value for any_space_or_comment
  class AnySpaceOrCommentMemo
    def initialize(has_live_lf, text)
      @has_live_lf = has_live_lf
      @text = text
    end

    def has_live_lf?
      @has_live_lf
    end

    def text
      @text
    end
  end

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

    # Called when space handling meets "\n".
    # Not called from comment handling.
    def space_rule_live_lf_callback()
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
      regexp_notrace(/.*$/)
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

    # treat space or comment.
    memoize def any_space_or_comment()
      is_callback_success = true
      is_live_code_have_lf = false
      prev_pos = current_pos()
      bt_loop do
        # keep skipping 
        live_lf = bt_branch(
          proc{ comment(); nil },
          proc{ regexp(/[ \t\r]+/); nil },
          proc{ str("\n") }
        )

        if live_lf == "\n"
          is_live_code_have_lf = true

          # New line callback. if error happen in callback, whole space matching fails.
          # this flow is provided only for here-document-like syntax.
          catch(:failed) do
            is_callback_success = false
            space_rule_live_lf_callback()
            is_callback_success = true
          end
          unless is_callback_success
            # break bt_loop
            failed()
          end
        end
      end
      unless is_callback_success
        # if error happen in callback, whole space matching fails.
        failed()
      end
      after_pos = current_pos()

      # This is special process to return text before current position
      return AnySpaceOrCommentMemo.new(is_live_code_have_lf, @text.byteslice(prev_pos ... after_pos))
    end

    # Spaces (must contain newline)
    trace def lf()
      spaceinfo = any_space_or_comment()
      if spaceinfo.has_live_lf?()
        return spaceinfo.text
      else
        failed()
      end
    end

    # Spaces (without newline)
    trace def inline_sp()
    spaceinfo = any_space_or_comment()
      if spaceinfo.has_live_lf?()
        failed()
      elsif spaceinfo.text.size == 0
        failed()
      else
        return spaceinfo.text
      end
    end
    
    # Spaces (without newline, could be blank)
    def inline_sp?()
      spaceinfo = any_space_or_comment()
      if spaceinfo.has_live_lf?()
        failed()
      else
        return spaceinfo.text
      end
    end
    
    # Spaces (allow newline)
    trace def sp()
      spaceinfo = any_space_or_comment()
      if spaceinfo.text.size == 0
        failed()
      else
        return spaceinfo.text
      end
    end
    
    # Spaces (allow newline, could be blank)
    def sp?()
      spaceinfo = any_space_or_comment()
      spaceinfo.text
    end

  end
end
end