class ValidateDestinationCommand < BaseCommand
  def call
    destination = Setting.fetch(:destination_root)

    if destination.blank?
      context.fail!(message: "Destination directory is not configured. Go to Settings to set it.")
      return
    end

    unless SystemUtils.directory?(destination) && SystemUtils.writable?(destination)
      context.fail!(message: "Destination directory '#{destination}' does not exist or is not writable.")
    end
  end
end
