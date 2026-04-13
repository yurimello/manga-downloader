class CommandChain
  attr_reader :result, :errors, :context

  def initialize(commands, context = {})
    @commands = commands
    @context = context
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
        break
      end
    end

    self
  end

  def success?
    @errors.empty?
  end
end
