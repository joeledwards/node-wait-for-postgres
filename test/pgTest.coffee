assert = require 'assert'
durations = require 'durations'
waitForPg = require '../src/index.coffee'

describe "wait-for-postgres", ->
    it "should retry until postgres is up", (done) ->
        watch = durations.stopwatch().start()

        # TODO: test wait for connection

    it "should retury until the query succeeds", (done) ->
        watch = durations.stopwatch()

        # TODO: test wait for successful query


    it "should timeout after waiting the max timeout", (done) ->
        watch = durations.stopwatch().start()

        # TODO: test timeout

