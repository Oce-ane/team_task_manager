# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    user
    message { "You have a new notification" }
    read { false }
    notifiable { association :comment }

    trait :read do
      read { true }
    end
  end
end
