module LoggregatorEmitter
  class Target
    attr_reader :app_id

    def initialize(app_id)
      @app_id = app_id
    end
  end
end
