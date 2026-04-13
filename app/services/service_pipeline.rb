class ServicePipeline
  attr_reader :context, :error

  def initialize(steps, context = {}, observers: [])
    @steps = steps
    @context = context
    @observers = observers
    @error = nil
  end

  def call
    @steps.each do |step|
      break if cancelled?

      step.new(@context, observers: @observers).call
    rescue => e
      @error = e
      notify(:on_error, e)
      break
    end

    self
  end

  def success?
    @error.nil?
  end

  private

  def notify(event, *args)
    @observers.each { |o| o.public_send(event, @context, *args) }
  end

  def cancelled?
    download = @context[:download]
    download && download.reload.cancelled?
  end
end
