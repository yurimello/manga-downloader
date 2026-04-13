class ValidateDestinationCommand < BaseCommand
  def call
    if Setting.fetch(:destination_root).blank?
      error = StandardError.new("Destination directory is not configured. Go to Settings to set it.")
      context.observers&.each { |o| o.on_error(context, error) }
      context.fail!(message: error.message)
    end
  end
end
