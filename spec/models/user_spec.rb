# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { should have_many(:memberships).dependent(:destroy) }
    it { should have_many(:projects).through(:memberships) }
  end

  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to have_secure_password }

    it "is valid with valid attributes" do
      expect(build(:user)).to be_valid
    end

    it "is invalid with a malformed email" do
      expect(build(:user, email: "not-an-email")).not_to be_valid
    end

    it "is invalid with a password shorter than 8 characters" do
      expect(build(:user, password: "short")).not_to be_valid
    end
  end
end
