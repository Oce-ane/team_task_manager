# frozen_string_literal: true

FactoryBot.define do
  factory :task do
    project
    sequence(:title) { |n| "Task #{n}" }
    description { "A test task" }
    status { :todo }
    priority { :low }

    trait :in_progress do
      status { :in_progress }
    end

    trait :done do
      status { :done }
    end

    trait :high_priority do
      priority { :high }
    end

    trait :medium_priority do
      priority { :medium }
    end
  end
end
