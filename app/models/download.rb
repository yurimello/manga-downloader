class Download < ApplicationRecord
  enum :status, { queued: 0, downloading: 1, packing: 2, completed: 3, failed: 4, cancelled: 5 }

  has_many :download_volumes, dependent: :destroy
  has_many :download_logs, dependent: :destroy

  validates :url, presence: true

  scope :active, -> { where(status: [:queued, :downloading, :packing]) }
  scope :completed_or_failed, -> { where(status: [:completed, :failed]) }

  def active?
    queued? || downloading? || packing?
  end

  def log!(message, level: :info)
    log = download_logs.create!(message: message, level: level)
    ActionCable.server.broadcast("download_#{id}", {
      type: "log_added",
      download_id: id,
      message: message,
      level: level.to_s,
      timestamp: log.created_at.iso8601
    })
    log
  end
end
