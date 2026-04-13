class CreateDownloadVolumes < ActiveRecord::Migration[8.1]
  def change
    create_table :download_volumes do |t|
      t.references :download, null: false, foreign_key: true
      t.string :manga_id, null: false
      t.string :volume, null: false
      t.integer :chapters_count, default: 0
      t.integer :pages_count, default: 0
      t.timestamps
    end

    add_index :download_volumes, [:manga_id, :volume], unique: true
  end
end
