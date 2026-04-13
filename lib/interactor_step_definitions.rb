module InteractorStepDefinitions
  def step(klass, **defaults)
    step_definitions << [klass, defaults]
    organize(*step_definitions.map(&:first))
  end

  def dependency(**defaults)
    @dependencies = (@dependencies || {}).merge(defaults)
  end

  def step_definitions
    @step_definitions ||= []
  end

  def dependencies
    @dependencies || {}
  end
end
