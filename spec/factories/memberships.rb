# frozen_string_literal: true

FactoryBot.define do
  factory :membership do
    user
    project
    role { :member }

    trait :owner do
      role { :owner }
    end
  end
end
