class ServicePipeline
  attr_reader :context, :error

  def initialize(steps, context = {})
    @steps = steps
    @context = context
    @error = nil
  end

  def call
    @steps.each do |step|
      break if cancelled?

      step.new(@context).call
    rescue => e
      @error = e
      break
    end

    self
  end

  def success?
    @error.nil?
  end

  private

  def cancelled?
    download = @context[:download]
    download && download.reload.cancelled?
  end
end
