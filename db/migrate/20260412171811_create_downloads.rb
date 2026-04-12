class CreateDownloads < ActiveRecord::Migration[8.1]
  def change
    create_table :downloads do |t|
      t.string :url
      t.string :volumes
      t.integer :status, default: 0
      t.string :title
      t.string :manga_id
      t.string :source
      t.text :error_message
      t.integer :progress, default: 0
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end
