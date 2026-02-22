# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notification, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:notifiable) }
  end

  describe "validations" do
    it { should validate_presence_of(:message) }
  end

  describe "scopes" do
    let(:user) { create(:user) }
    let!(:unread) { create(:notification, user: user) }
    let!(:read) { create(:notification, :read, user: user) }

    it "returns only unread notifications" do
      expect(Notification.unread).to contain_exactly(unread)
    end
  end
end
