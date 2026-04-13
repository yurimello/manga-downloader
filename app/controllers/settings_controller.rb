class SettingsController < ApplicationController
  def edit
    @max_concurrent = Setting.fetch(:max_concurrent_processes)
    @destination_root = Setting.fetch(:destination_root)
  end

  def update
    Setting.store(:max_concurrent_processes, params[:max_concurrent_processes])
    Setting.store(:destination_root, params[:destination_root])
    SettingsObserver.saved(:destination_root)
    redirect_to edit_settings_path, notice: "Settings saved."
  rescue ActiveRecord::RecordInvalid => e
    SettingsObserver.validation_failed(e.record.errors.full_messages)
    redirect_to edit_settings_path, alert: e.record.errors.full_messages.join(", ")
  end
end
