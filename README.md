# Loggregator Emitter 

[![Build Status](https://travis-ci.org/cloudfoundry/loggregator_emitter.png?branch=master)](https://travis-ci.org/cloudfoundry/loggregator_emitter) [![Coverage Status](https://coveralls.io/repos/cloudfoundry/loggregator_emitter/badge.png?branch=master)](https://coveralls.io/r/cloudfoundry/loggregator_emitter?branch=master)

### About

This gem provides an API to emit messages to the loggregator agent from Ruby applications.

Create an emitter object with the loggregator router host and port, a source name of the emitter, and a shared secret (for signing).

Call emit() or emit_error() on this emitter with the application GUID and the message string.

##### A valid source name is any 3 character string.   Some common component sources are:

 	API (Cloud Controller)
 	RTR (Go Router)
 	UAA
 	DEA
 	APP (Warden container)
 	LGR (Loggregator)

### Setup

    Add the loggregator_emitter gem to your gemfile.

    gem "loggregator_emitter"

### Sample Workflow

    require "loggregator_emitter"

    emitter = LoggregatorEmitter::Emitter.new("10.10.10.16:38452", "API")

    app_guid = "a8977cb6-3365-4be1-907e-0c878b3a4c6b" # The GUID(UUID) for the user's application

    emitter.emit(app_guid,message) # Emits messages with a message type of OUT

    emitter.emit_error(app_guid,error_message) # Emits messages with a message type of ERR

### Regenerating Protobuf library
    protoc --beefcake_out lib/loggregator_messages -I lib/loggregator_messages lib/loggregator_messages/log_message.proto

### Versioning

This gem is versioned using [semantic versioning](http://semver.org/).
