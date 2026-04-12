FactoryBot.define do
  factory :download do
    url { "https://mangadex.org/title/ffc29425-4682-4602-8328-005ed75c5316/a-girl-on-the-shore" }
    status { :queued }
    progress { 0 }

    trait :downloading do
      status { :downloading }
      title { "A Girl on the Shore" }
      manga_id { "ffc29425-4682-4602-8328-005ed75c5316" }
      started_at { Time.current }
    end

    trait :completed do
      status { :completed }
      title { "A Girl on the Shore" }
      progress { 100 }
      completed_at { Time.current }
    end

    trait :failed do
      status { :failed }
      error_message { "Connection refused" }
      completed_at { Time.current }
    end

    trait :with_volumes do
      volumes { "1, 2, 3" }
    end
  end
end
