FactoryBot.define do
  factory :download_log do
    download
    message { "Processing..." }
    level { :info }
  end
end
