# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommentNotificationJob, type: :job do
  let(:project) { create(:project) }
  let(:author) { create(:user, name: "Alice") }
  let(:assignee) { create(:user) }
  let(:task) { create(:task, project: project, title: "Fix bug", assignee: assignee) }

  describe "#perform" do
    context "when the task has an assignee different from the comment author" do
      it "creates a notification for the assignee" do
        comment = create(:comment, task: task, user: author)

        expect {
          described_class.perform_now(comment.id)
        }.to change(Notification, :count).by(1)

        notification = Notification.last
        expect(notification.user).to eq(assignee)
        expect(notification.notifiable).to eq(comment)
        expect(notification.message).to include("Alice")
        expect(notification.message).to include("Fix bug")
        expect(notification.read).to be false
      end
    end

    context "when the comment author is the assignee" do
      it "does not create a notification" do
        comment = create(:comment, task: task, user: assignee)

        expect {
          described_class.perform_now(comment.id)
        }.not_to change(Notification, :count)
      end
    end

    context "when the task has no assignee" do
      let(:task) { create(:task, project: project, assignee: nil) }

      it "does not create a notification" do
        comment = create(:comment, task: task, user: author)

        expect {
          described_class.perform_now(comment.id)
        }.not_to change(Notification, :count)
      end
    end

    context "when the comment no longer exists" do
      it "does not raise and does not create a notification" do
        expect {
          described_class.perform_now(-1)
        }.not_to change(Notification, :count)
      end
    end
  end
end
