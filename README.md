# Loggregator Emitter [![Build Status](https://travis-ci.org/cloudfoundry/loggregator_emitter.png?branch=master)](https://travis-ci.org/cloudfoundry/loggregator_emitter)

### About

This gem provides an API to emit messages to the loggregator agent from Ruby applications.

Create an emitter object with the loggregator router host and port, and source type of the emitter.

Call emit() or emit_error() on this emitter with the application GUID and the message string.

### Valid source types are:

 	LogMessage::SourceType::CLOUD_CONTROLLER
 	LogMessage::SourceType::ROUTER
 	LogMessage::SourceType::UAA
 	LogMessage::SourceType::DEA
 	LogMessage::SourceType::WARDEN_CONTAINER

### Sample Workflow

    require "loggregator_emitter"

    emitter = LoggregatorEmitter::Emitter.new("10.10.10.16:38452", LogMessage::SourceType::CLOUD_CONTROLLER)

    emitter.emit(app_id,message)

    emitter.emit_error(app_id,error_message)

