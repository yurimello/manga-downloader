class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  def self.fetch(key, default = nil)
    find_by(key: key.to_s)&.value || default
  end

  def self.store(key, value)
    setting = find_or_initialize_by(key: key.to_s)
    setting.update!(value: value.to_s)
    setting
  end
end
