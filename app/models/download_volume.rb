class DownloadVolume < ApplicationRecord
  belongs_to :download

  validates :manga_id, presence: true
  validates :volume, presence: true, uniqueness: { scope: :manga_id }

  def self.downloaded_volumes_for(manga_id)
    where(manga_id: manga_id).pluck(:volume).to_set
  end
end
