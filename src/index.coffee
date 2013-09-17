#!/usr/bin/env coffee

express = require 'express'
redis = require 'redis'
aws = require 'aws-sdk'
models = require './models'


app = express()
app.use express.bodyParser()


app.get '/', (req, res) ->
    res.send 403

app.post '/', (req, res) ->
    Message = models.Message.types[req.body.type]
    message = new Message req.body.name, req.body.destination, req.body.payload
    schedule = new models.Schedule req.body.name, req.body.schedule
    messenger = new models.Messenger req.body.name, message, schedule

    messenger.exists (err, exists) ->
        shouldReplace = req.body.replace ? yes

        if exists and not shouldReplace
            res.send 200
        else
            messenger.save -> res.send 201


app.delete '/', (req, res) ->
    Messenger.delete req.body.name, ->
        res.send 200

app.listen 3333, (err) ->
    if err
        console.log err
    else
        console.log 'cron-messenger listening on port 3333'

main = ->
    return if main.locked

    main.locked = yes
    models.Messenger.dispatchAll (err) ->
        if err then console.log err
        main.locked = no


setInterval main, 1000