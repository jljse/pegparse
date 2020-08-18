require "test_helper"
require "pegparse"

class PegparseTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Pegparse::VERSION
  end
end
