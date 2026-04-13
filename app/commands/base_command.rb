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

  def then(command_class)
    return self unless success?

    command = command_class.new(@context)
    command.call
    @errors.concat(command.errors)
    @result = command.result if command.success?
    @context = command.context
    self
  end

  private

  def add_error(message)
    @errors << message
  end
end
