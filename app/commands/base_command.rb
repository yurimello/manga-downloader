class BaseCommand
  attr_reader :result, :errors, :context

  def initialize(context = {})
    @context = context
    @errors = []
    @result = nil
  end

  def call
    raise NotImplementedError
  end

  def success?
    @errors.empty?
  end

  private

  def add_error(message)
    @errors << message
  end
end
