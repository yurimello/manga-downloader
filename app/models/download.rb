class Download < ApplicationRecord
  include Observable

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
    notify(:on_log_added, message, level)
    log
  end
end
