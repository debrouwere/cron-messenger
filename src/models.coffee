###
A cron task consists of a `Messenger`, which we 
will ask to send a `Message` one or more times,
according to a `Schedule`.
###


_ = require 'underscore'
async = require 'async'
later = require 'later'
timing = require './timing'
{noop, retry} = require './utils'
redis = require 'redis'
colors = require 'colors'
AWS = require 'aws-sdk'
cache = redis.createClient()


credentials = 
    accessKeyId: process.env.AWS_ACCESS_KEY_ID
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
    region: process.env.AWS_REGION

sqs = new AWS.SQS credentials


class Message
    constructor: (@name, @destination, @payload) ->
        _.bindAll this, 'save', 'send'

        # payloads can be JSON objects or strings, but 
        # many messaging protocols only work with strings
        if typeof @payload is 'object'
            @serializedPayload = JSON.stringify @payload
        else
            @serializedPayload = @payload

    save: (callback) ->
        type = @constructor.name
        data = JSON.stringify {type, @destination, @payload}
        cache.hset ['messages', @name, data], callback


Message.load = (name, callback=noop) ->
    cache.hget ['messages', name], (err, data) ->
        if err then return callback err

        {type, destination, payload} = JSON.parse data
        message = new exports[type] name, destination, payload
        callback null, message


Message.delete = (name, callback=noop) ->
    cache.hdel ['messages', name], callback


class ConsoleMessage extends Message
    send: (callback) ->
        date = new Date().toISOString()
        console.log "[#{date}]", "#{@name} -> #{@destination}".bold
        console.log @serializedPayload.grey
        callback null

class WebhookMessage extends Message
    send: (callback) ->
        callback null

class SQSMessage extends Message
    send: (callback) ->
        params =
            QueueUrl: @destination
            MessageBody: @serializedPayload

        sqs.sendMessage params, (err) ->
            if err then console.log '[cron-messenger] SQSMessage Error:', err
            callback err

class IronMessage extends Message
    send: (callback) ->
        callback null


Message.types = 
    sqs: SQSMessage
    webhook: WebhookMessage
    iron: IronMessage
    console: ConsoleMessage


class Schedule
    constructor: (@name, options) ->
        _.bindAll this, 'save', 'next', 'score'

        defaults =
            start: new Date()
            stop: Infinity

        schedule = _.defaults options, defaults
        _.extend this, schedule

        # JSON translates Infinity into null, 
        # so let's translate that back
        if @stop is null then @stop = Infinity

        if typeof @start is 'string'
            @start = new Date @start
        if typeof @stop is 'string'
            @stop = new Date @stop        

    save: (callback=noop) ->
        data = JSON.stringify {@start, @stop, @cron, @decay}
        cache.hset ['schedules', @name, data], callback

    next: (now) ->
        now ?= new Date()
        tomorrow = new Date now.getTime() + later.d.range * 1000

        if not (@start <= now < @stop)
            return NaN

        schedule = later.schedule later.parse.cron @cron

        if @decay
            ticks = schedule.next Infinity, (later.d.start now), tomorrow
            ticksWithDecay = timing.decay ticks, @start, @decay, now
            nextTick = timing.next ticksWithDecay, now
        else
            nextTick = schedule.next 1, now

        nextTick or NaN

    score: ->
        next = @next()

        if next
            next.getTime()
        else
            NaN


Schedule.load = (name, callback=noop) ->
    cache.hget ['schedules', name], (err, data) ->
        options = JSON.parse data
        schedule = new Schedule name, options
        callback null, schedule


Schedule.delete = (name, callback=noop) ->
    cache.hdel ['schedules', name], callback


class Messenger
    constructor: (@name, @message, @schedule) ->
        _.bindAll this, 'save', 'dispatch', 'saveMessenger', 'remove', 'update'

    exists: (callback) ->
        cache.zrank ['messengers', @name], (err, res) ->
            callback err, res isnt null

    saveMessenger: (callback=noop) ->
        score = @schedule.score()
        cache.zadd ['messengers', score, @name], callback        

    save: (callback=noop) ->
        async.parallel [@message.save, @schedule.save, @saveMessenger], callback

    # the system works in such a way that failed messages will be tried 
    # over and over and over again because they don't ever get removed
    # from Redis... so instead we retry a couple of times and if no luck, 
    # we pass on the OK anyway
    dispatch: (callback=noop) ->
        attemptToSend = retry @message.send, 3
        attemptToSend callback

    remove: (callback=noop) ->
        Messenger.deleteRelated @name, callback

    update: (callback=noop) ->
        score = @schedule.score()

        if score
            @saveMessenger callback
        else
            @remove callback


Messenger.load = (name, callback=noop) ->
    tasks =
        message: async.apply Message.load, name
        schedule: async.apply Schedule.load, name

    async.parallel tasks, (err, {message, schedule}) ->
        callback err, new Messenger name, message, schedule

Messenger.delete = (name, callback=noop) ->
    cache.zrem ['messengers', name], callback

Messenger.deleteRelated = (name, callback=noop) ->
    stores = [Messenger.delete, Message.delete, Schedule.delete]
    async.applyEach stores, name, callback

Messenger.dispatchAll = (callback=noop) ->
    now = new Date().getTime()

    fetch = (done) ->
        cache.zrangebyscore ['messengers', 0, now], done
    load = (names, done) ->
        async.map names, Messenger.load, done
    dispatch = (messenger, done) ->
        async.series [messenger.dispatch, messenger.update], done
    dispatchAll = (messengers, done) ->
        async.each messengers, dispatch, done

    async.waterfall [fetch, load, dispatchAll], callback


exports.Message = Message
exports.ConsoleMessage = ConsoleMessage
exports.SQSMessage = SQSMessage
exports.IronMessage = IronMessage
exports.WebhookMessage = WebhookMessage
exports.Schedule = Schedule
exports.Messenger = Messenger

