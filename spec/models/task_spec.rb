# frozen_string_literal: true

require "rails_helper"

RSpec.describe Task, type: :model do
  describe "associations" do
    it { should belong_to(:project) }
    it { should belong_to(:assignee).class_name("User").optional }
  end

  describe "validations" do
    it { should validate_presence_of(:title) }
  end

  describe "enums" do
    it { should define_enum_for(:status).with_values(todo: 0, in_progress: 1, done: 2) }
    it { should define_enum_for(:priority).with_values(low: 0, medium: 1, high: 2) }
  end

  describe "scopes" do
    let(:project) { create(:project) }
    let(:user) { create(:user) }

    let!(:todo_task) { create(:task, project: project, status: :todo) }
    let!(:done_task) { create(:task, :done, project: project) }
    let!(:high_task) { create(:task, :high_priority, :in_progress, project: project) }
    let!(:assigned_task) { create(:task, :done, project: project, assignee: user) }

    it "filters by status" do
      expect(Task.by_status(:todo)).to contain_exactly(todo_task)
    end

    it "filters by priority" do
      expect(Task.by_priority(:high)).to contain_exactly(high_task)
    end

    it "filters by assignee" do
      expect(Task.by_assignee(user.id)).to contain_exactly(assigned_task)
    end
  end
end
