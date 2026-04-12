class DownloadLog < ApplicationRecord
  belongs_to :download

  enum :level, { info: 0, warn: 1, error: 2 }
end
