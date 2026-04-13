module InteractorStepDefinitions
  def step(klass, **defaults)
    step_definitions << [klass, defaults]
    organize(*step_definitions.map(&:first))
  end

  def step_default(**defaults)
    @step_defaults = (@step_defaults || {}).merge(defaults)
  end

  def step_definitions
    @step_definitions ||= []
  end

  def global_defaults
    @step_defaults || {}
  end
end
