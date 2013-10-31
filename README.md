# Loggregator Emitter [![Build Status](https://travis-ci.org/cloudfoundry/loggregator_emitter.png?branch=master)](https://travis-ci.org/cloudfoundry/loggregator_emitter)

### About

This gem provides an API to emit messages to the loggregator agent from Ruby applications.

Create an emitter object with the loggregator router host and port, and source type of the emitter.

Call emit() or emit_error() on this emitter with the application GUID and the message string.

### Setup

    Add the loggregator_emitter gem to your gemfile.

    gem "loggregator_emitter"

### Sample Workflow

    require "loggregator_emitter"

    emitter = LoggregatorEmitter::Emitter.new("10.10.10.16:38452", LogMessage::SourceType::CLOUD_CONTROLLER)

    app_guid = "a8977cb6-3365-4be1-907e-0c878b3a4c6b" # The GUID(UUID) for the user's application

    emitter.emit(app_guid,message) # Emits messages with a message type of OUT

    emitter.emit_error(app_guid,error_message) # Emits messages with a message type of ERR

### Regenerating Protobuf library
    protoc --beefcake_out lib/loggregator_messages -I lib/loggregator_messages lib/loggregator_messages/log_message.proto

### Versioning

This gem is versioned using [semantic versioning](http://semver.org/).
