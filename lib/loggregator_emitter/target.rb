module LoggregatorEmitter
  class Target
    attr_reader :organization_id, :space_id, :app_id

    def initialize(org_id, space_id, app_id)
      @organization_id = org_id
      @space_id = space_id
      @app_id = app_id
    end
  end
end
