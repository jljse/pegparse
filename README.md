
# Pegparse

Pegparse is library to create recursive descent parser.

This provide parser base class which has helper methods.
- PEG semantics
- binary-operations
- quoted-strings
- comments aware skip
- indent level checking
- here-documents


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pegparse'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install pegparse


## Usage

1. Create class inherit `Pegparse::ParserBase` class.
2. Set entrypoint with `start_rule_symbol`.
3. Write parsing rule by method.

```ruby
require 'pegparse'

class MyParser < Pegparse::ParserBase
  def initialize(scanner_or_context)
    super(scanner_or_context)
    self.start_rule_symbol = :number_rule
  end

  def number_rule
    digits = one_or_more {  # digits becomes ['1', '2']
      read(/[0-9]/)
    }
    decimal = optional {  # decimal is '34'
      decimal_rule()
    }
    return [digits.join.to_i, decimal&.to_i]
  end

  def decimal_rule
    read('.')
    read(/[0-9]+/)  # decimal_rule returns '34'
  end
end

MyParser.new(nil).parse(StringScanner.new('12.34'))  # => [12, 34]
```

### Core methods

- `raed(str_or_regexp)` : Try to consume input. If success, return string. If failed, make backtrack.
- `peek(str_or_regexp)` : Peek input. If success, return string.
- `peek{ ... }` : Peek input. If success, return block result.
- `optional{ ... }` : Match only available. (PEG's option operator('?'))
- `zero_or_more{ ... }` : Repeat matching. (PEG's repeat operator('*'))
- `one_or_more{ ... }` : Repeat matching. (PEG's repeat operator('+'))
- `choice(proc, proc, ...)` : Choice matching (PEG's choice operator('/'))
- `backtrack()` : Make backtrack.

### Helper methods

- `sp()` : Spaces. (Space charactors or comments)
- `inline_sp()` : Spaces without line feed.
- `deeper_sp()` : Spaces without line feed or have deeper indent than previous line.
- `lf()` : Spaces contain line feed.
- `separative(separator){ ... }` : Repeat matching with separator.
- `string_like(end_pattern, normal_pattern){ ... }` : String like "" and ''. Block is for special char handlings like escaping.
- `borrow_next_line{ ... }` : Skip current line and parse next line temporaliry. Used lines become unmatchable with normal process. (For here-document)
- `borrowed_area()` : Only matches to lines used by `borrow_next_line`.
- `Pegparse::BiopRuleChain` : Binary operator helper class.

You can see sample parser implementations under `/samples`.

### debug

Use `Pegparse::ParserCore#best_errors` to find parsing error location.
`best_errors` returns farthest location where parsing failed.
It also returns the deepest rule name.
You can improve message by decorating your rule method with `rule`.
```ruby
  rule def your_rule
    ...
  end
```


### VSCode

If you want to debug your parser with VSCode by breakpoint or step-by-step execution, add this config to your launch.json.
(debug gem newer than 1.4.0 required)
Then all process inside gem will be skipped while VSCode step-by-step execution.

```json
    {
        "type": "rdbg",
        "name": "Debug specified user program with rdbg",
        "request": "launch",
        "script": "${workspaceFolder}/YOUR_PARSER_HERE.rb",
        "args": [],
        "env": {
            "RUBY_DEBUG_SKIP_PATH": [
                "YOUR_GEM_DIRECTORY_HERE",
            ],
        }
    }
```



## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jljse/pegparse.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).