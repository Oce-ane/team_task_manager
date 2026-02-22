# frozen_string_literal: true

FactoryBot.define do
  factory :comment do
    task
    user
    sequence(:content) { |n| "Comment #{n}" }
  end
end
