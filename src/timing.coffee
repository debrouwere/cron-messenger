_ = require 'underscore'

exports.decay = (timeseries, start, lambda, now) ->
    now ?= new Date()
    # linear skip
    linear = 1 + Math.floor (now - start) / lambda
    # geometric skip
    geo = Math.pow 2, linear - 1

    timeseries.filter (tick, i) -> i % geo is 0

exports.next = (ticks, now) ->
    now ?= new Date()
    _.find ticks, (tick) -> tick - now > 1000