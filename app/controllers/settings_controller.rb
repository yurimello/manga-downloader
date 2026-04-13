class SettingsController < ApplicationController
  def edit
    @max_concurrent = Setting.fetch(:max_concurrent_processes)
    @destination_root = Setting.fetch(:destination_root)
  end

  def update
    Setting.store(:max_concurrent_processes, params[:max_concurrent_processes])
    Setting.store(:destination_root, params[:destination_root])
    redirect_to edit_settings_path, notice: "Settings saved."
  end
end
