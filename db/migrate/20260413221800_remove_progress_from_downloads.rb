class RemoveProgressFromDownloads < ActiveRecord::Migration[8.1]
  def change
    remove_column :downloads, :progress, :integer, default: 0
  end
end
