class ServicePipeline
  include Interactor::Organizer

  private

  def self.steps(*step_classes)
    organize(*step_classes)
  end
end
