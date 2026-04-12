class CreateDownloadLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :download_logs do |t|
      t.references :download, null: false, foreign_key: true
      t.text :message
      t.integer :level

      t.timestamps
    end
  end
end
