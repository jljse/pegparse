require_relative 'parser_core'

# Parser base class (reusable rules)
class Pegparse::ParserBase < Pegparse::ParserCore
  def initialize(scanner_or_context)
    super(scanner_or_context)
  end

  # match for spaces
  def _
    one_or_more {
      choice(
        ->{ read(/[ \t\r]+/) },
        ->{ read(/\n/) },
        ->{ borrowed_area() },
        ->{ line_comment() },
        ->{ block_comment() },
      )
    }
  end

  def line_comment
    read(/#[^\n]*/)
  end

  rule def block_comment
    ret = ""
    ret << read('/*')
    ret << zero_or_more {
      part = read(/[^*]*/)
      break if peek('*/')
      part << '*' if optional('*')
    }.join
    ret << read('*/')
    ret
  end

  # match for spaces
  def sp
    optional{ _ }
  end

  # match for spaces without newline
  def inline_sp
    before_line, * = @context.line_counter.position(@context.scanner.pos)
    ret = optional{ _ }
    after_line, * = @context.line_counter.position(@context.scanner.pos)
    backtrack() if before_line != after_line
    ret
  end

  # match for spaces (if spaces cross to the next line, it must have deeper indent than previous line)
  def deeper_sp
    base_line, * = @context.line_counter.position(@context.scanner.pos)
    base_indent = @indent_stack.last
    raise StandardError unless base_indent
    ret = optional{ _ }
    new_line, * = @context.line_counter.position(@context.scanner.pos)
    new_indent = @context.line_counter.indent(@context.scanner.pos)
    backtrack() if base_line != new_line && base_indent >= new_indent
    ret
  end

  # match for spaces (must contain newline)
  def lf
    before_line, * = @context.line_counter.position(@context.scanner.pos)
    ret = optional{ _ }
    after_line, * = @context.line_counter.position(@context.scanner.pos)
    backtrack() if before_line == after_line
    ret
  end

  # loop with separator
  # @param separator_matcher [Regexp, String, Proc]
  # @param allow_additional_separator [Boolean]  Allow redundant separator at tail.
  def separative(separator_matcher, allow_additional_separator: false, &repeat_block)
    if separator_matcher.is_a? Proc
      separator_proc = separator_matcher
    else
      separator_proc = ->{
        sp()
        read(separator_matcher)
        sp()
      }
    end

    ret = []
    optional {
      ret << repeat_block.call()
      rest = zero_or_more {
        separator_proc.call()
        repeat_block.call()
      }
      ret.concat(rest)
      if allow_additional_separator
        optional {
          separator_proc.call()
        }
      end
    }
    ret
  end
end
