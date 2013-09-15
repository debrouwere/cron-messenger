Don't you hate how SQS doesn't support visibility delays over 15 minutes? Doesn't it annoy you that AWS data pipelines are a buck a month for a single cron entry? Do you have tasks with start and end dates, or perhaps tasks that need to run less often as time passes?

`cron-messenger` allows you to efficiently specify and run hundreds of thousands of crons on a single EC2 machine. The caveat: your cron can't actually execute anything but instead will send a message to a message queue, call a webhook or otherwise notify _something else_ to take care of whatever needs to happen.

The messenger is a node.js application and uses Redis as its back-end. Because Redis is an in-memory database, make sure that your box has enough memory. An EC2 micro can roughly store about a million jobs.

# You may also like...

* If you're looking for a more general purpose cron-like tool for your AWS based data processing, [AWS Data Pipeline](http://aws.amazon.com/datapipeline/) is probably what you need.
* If you're looking for a hosted solution for running delayed tasks and running tasks on a schedule, [IronWorker](http://dev.iron.io/worker/scheduling/) and [PiCloud](http://blog.picloud.com/2010/08/10/crons-in-the-cloud/) do what you want.
* If you're looking for a cron-slash-data-pipeline tool that is very robust and not tied to Amazon's infrastructure, try AirBnB's [chronos](https://github.com/airbnb/chronos).