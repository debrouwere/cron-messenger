request = require 'request'

article = 'http://www.theguardian.com/world/2013/sep/05/sarin-syrian-chemical-weapons-cameron'

params =
    uri: 'http://localhost:3333/'
    json: yes
    body:
        name: article
        type: 'sqs'
        destination: 'pollster'
        schedule:
            cron: '*/1'
            stop: new Date().getTime() + 1000 * 60 * 3
        payload:
            url: article

request.post params, (error, response, body) ->
    console.log body