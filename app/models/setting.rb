class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validate :destination_root_must_be_writable, if: -> { key == "destination_root" && value.present? }

  def self.fetch(key, default = nil)
    find_by(key: key.to_s)&.value || default
  end

  def self.store(key, value)
    setting = find_or_initialize_by(key: key.to_s)
    setting.value = value.to_s
    setting.save!
    setting
  end

  private

  def destination_root_must_be_writable
    unless SystemUtils.directory?(value) && SystemUtils.writable?(value)
      errors.add(:value, "directory '#{value}' does not exist or is not writable")
    end
  end
end
