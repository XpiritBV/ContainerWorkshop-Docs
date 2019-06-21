# Lab 10 - Free exploration

Goals for this lab is to experiment with a number of improvements to the solution. You are free to investigate, explore and experiment.

## Some ideas

Here are a couple of ideas of improvements to the solution:

### Resilient proxy

The current proxy does not have any robust error handling or retry logic. You can improve the current implementation by adding support for retry and circuit breaker. The Polly NuGet package might come in handy here.

### AzDO pipelines per service

Instead of releasing an entire composition you may want to selectively update services in your cluster.

Create a single release pipeline per service.

### Azure DevSpaces

Have a look at the potential of Azure DevSpaces for development with multiple features and teams.
