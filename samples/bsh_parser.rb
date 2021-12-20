require_relative '../lib/pegparse'
require 'set'

module Pegparse::Sample
end

class Pegparse::Sample::BshParser < Pegparse::ParserBase
  def initialize(context_or_scanner)
    super(context_or_scanner)
    self.start_rule_symbol = :start_rule
  end

  def line_comment
    read(/#.*/)
  end

  def block_comment
    backtrack
  end

  def inline_sp
    read(/( |\\\n)*/)
  end

  def lf
    choice(
      ->{ super() },
      ->{
        sp()
        read(';')
      },
    )
  end

  def keyword(key)
    read(key)
    backtrack if peek(/[A-Za-z0-9_]/)
  end

  def start_rule
    ret = pipelines()
    sp()
    ret
  end

  def pipelines
    zero_or_more {
      sp()
      pipeline()
    }
  end

  BshBiopParser = Pegparse::BiopRuleChain.based_on(self) do
    def operator_sp
      inline_sp()
    end

    def operand_sp
      inline_sp()
    end
  end
  rule def pipeline
    biop_parser = BshBiopParser.new(nil)
    biop_parser
      .left_op(['&&', '||'])
      .left_op('|')
      .term(->{ sentence() })
    ret = biop_parser.parse(@context)

    pipeline_closer = optional{
      inline_sp()
      read(/[&;]/)
    }
    if pipeline_closer == '&'
      [:bg, ret]
    else
      ret
    end
  end

  rule def sentence
    choice(
      ->{ if_sentence() },
      ->{ while_sentence() },
      ->{ for_sentence() },
      ->{ case_sentence() },
      ->{ command_sentence() },
    )
  end

  rule def if_sentence
    keyword('if')
    sp()
    cond = pipeline()
    sp()
    keyword('then')
    sp()
    if_body = pipelines()
    elif_cond_bodies = zero_or_more {
      sp()
      keyword('elif')
      sp()
      elif_cond = pipeline()
      sp()
      keyword('then')
      sp()
      elif_body = pipelines()
      [elif_cond, elif_body]
    }
    else_body = optional{
      sp()
      keyword('else')
      sp()
      pipelines()
    }
    sp()
    keyword('fi')
    if else_body
      [:if, [cond, if_body], *elif_cond_bodies, [nil, else_body]]
    else
      [:if, [cond, if_body], *elif_cond_bodies]
    end
  end

  rule def while_sentence
    keyword('while')
    sp()
    backtrack
  end

  rule def for_sentence
    keyword('for')
    sp()
    var = assign_varname()
    sp()
    keyword('in')
    list = zero_or_more {
      inline_sp()
      normal_operand()
    }
    lf()
    sp()
    keyword('do')
    body = pipelines()
    keyword('done')
    [:for, var, list, body]
  end

  rule def case_sentence
    keyword('case')
    sp()
    backtrack
  end

  rule def command_sentence
    envs = zero_or_more {
      inline_sp()
      assign_exp()
    }
    main = optional{
      inline_sp()
      cmd = execute_target_exp()

      operands = zero_or_more {
        inline_sp()
        choice(
          ->{ redirect_operand() },
          ->{ normal_operand() }
        )
      }

      redirects, normals = operands.partition{|op| op[0] == :redirect}
      [cmd, redirects, operands]
    }
    backtrack if envs.empty? && !main

    main ? [:command, envs, main[1], main[0], *main[2]] : [:env, envs]
  end

  rule def assign_exp
    varname = assign_varname()
    read('=')
    val = assign_value()
    ['=', varname, val]
  end

  def assign_varname
    read(/[A-Za-z][A-Za-z0-9_]*/)
  end

  def assign_value
    normal_operand()
  end

  def execute_target_exp
    normal_operand()
  end

  rule def redirect_operand
    src_fd = optional{
      read(/[0-9]+/)
    }
    redirect = read(/>|>>|<|&>/)
    inline_sp()
    dest = normal_operand()
    [:redirect, redirect, src_fd, dest]
  end

  rule def normal_operand
    concats = one_or_more {
      choice(
        ->{ string_double_quote() },
        ->{ string_single_quote() },
        ->{ backquote_operand() },
        ->{ raw_operand() },
      )
    }
    if concats.size > 1
      [:concat, *concats]
    else
      concats.first
    end
  end

  def string_double_quote_special_process
    choice(
      ->{
        read('\\')
        escaped = read(/./m)
        case escaped
        when 'n'
          "\n"
        when "\n"
          ""
        else
          escaped
        end
      },
      ->{
        inline_command()
      },
      ->{
        variable_reference()
      }
    )
  end

  rule def string_double_quote
    read('"')
    ret = string_like('"', /[^"\\$]*/) {
      string_double_quote_special_process()
    }
    read('"')
    [:dquote, *ret]
  end

  rule def inline_command
    read('$(')
    body = pipelines()
    read(')')
    [:inline, body]
  end

  rule def variable_reference
    read('$')
    ref = choice(
      ->{
        name = read(/[A-Za-z0-9_]+/)
        [name, nil]
      },
      ->{
        read('{')
        name = read(/[A-Za-z0-9_]+/)
        substr = optional {
          variable_expansion()
        }
        read('}')
        [name, substr]
      },
    )
    [:var, *ref]
  end

  rule def variable_expansion
    choice(
      ->{
        read(':-')
        backtrack
      },
      ->{
        read('-')
        exp = variable_expansion_string()
        ['-', exp]
      },
    )
  end

  rule def variable_expansion_string
    ret = string_like('}', /[^\\$}]*/) {
      string_double_quote_special_process()
    }
    if ret.size > 1
      ret
    elsif ret.size == 1
      ret.first
    else
      ''
    end
  end

  rule def string_single_quote
    read("'")
    val = read(/[^']*/)
    read("'")
    val
  end

  rule def backquote_operand
    read('`')
    read('`')
    backtrack
  end

  RESERVED_WORDS = %w(
    if then elif else fi while do for in done
  ).to_set
  rule def raw_operand
    backtrack if RESERVED_WORDS.include?(peek(/[^\s]*/))

    ret = string_like(/[\s&|><;]/, /[^\s&|><;\\$]*/) {
      string_double_quote_special_process()
    }
    if ret.size > 1
      ret
    elsif ret.size == 0 || ret.first.size == 0
      backtrack()
    else
      ret.first
    end
  end
end
