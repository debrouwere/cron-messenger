_ = require 'underscore'
async = require 'async'
timing = require './timing'

exports.noop = ->

exports.retry = (fn, times, allowedErrors) ->
    (args..., callback) ->
        attempt = 0
        results = null
        err = null
        allowedError = yes
        redirected_fn = (done) -> 
            # exponential back-off
            wait = 1000 * Math.pow attempt, 2
            _.delay fn, wait, args..., ->
                attempt++
                [err, results] = arguments
                allowedError = isAllowedError err
                done()

        isAllowedError = (error) ->
            if not error
                yes
            else if allowedErrors
                _.detect allowedErrors, (type) -> err instanceof type
            else
                yes  

        shouldRetry = -> 
            hope = attempt < times
            return hope and err and not allowedError

        async.doWhilst redirected_fn, shouldRetry, ->
            filteredError = if allowedError then null else err
            callback filteredError, results
