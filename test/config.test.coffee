assert = require 'assert'
_ = require 'lodash'

config = require '../src/config.coffee'

# Expect a configuration to be valid
expectValid = (cfg) ->
  config.validate cfg
  .then (validated) ->
    patched = _.assign config.default(), cfg
    if not _.isEqual patched, validated
      console.log "Expected:", patched
      console.log "Actual:", validated
      throw new Error 'Config did not match expected'

# Expect a configuration to be invalid
expectInvalid = (cfg) ->
  config.validate cfg
  .catch -> null
  .then (validated) -> 
    if validated?
      console.log "validated config:", validated
      throw new Error 'Config should not have been valid'

# Tests
describe "wait-for-postgres' config module", ->
  it "should permit an null config", -> expectValid null
  it "should permit an undefined config", -> expectValid undefined

  it "should allow a connectTimeout of 0", -> expectValid {connectTimeout: 1}
  it "should not allow a connectTimeout of -1", -> expectInvalid {connectTimeout: -1}

  it "should allow a totalTimeout of 0", -> expectValid {totalTimeout: 0}
  it "should not allow a totalTimeout of -1", -> expectInvalid {totalTimeout: -1}

  it "should allow a host of 'a'", -> expectValid {host: 'a'}
  it "should not allow a null host", -> expectInvalid {host: null}
  it "should not allow an empty host of", -> expectInvalid {host: ''}

