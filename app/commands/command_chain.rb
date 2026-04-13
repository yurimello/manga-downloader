class CommandChain
  attr_reader :result, :errors, :context

  def initialize(commands, context = {}, observers: [])
    @commands = commands
    @context = context
    @observers = observers
    @errors = []
    @result = nil
  end

  def call
    @commands.each do |command_class|
      command = command_class.new(@context).call
      @context = command.context
      @result = command.result

      unless command.success?
        @errors.concat(command.errors)
        notify(:on_error, StandardError.new(@errors.join(", ")))
        break
      end
    end

    self
  end

  def success?
    @errors.empty?
  end

  private

  def notify(event, *args)
    @observers.each { |o| o.public_send(event, @context, *args) }
  end
end
