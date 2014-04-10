unless ENV['DISABLE_COVERAGE'] == 'true'
  require 'coveralls'
  Coveralls.wear!
end
