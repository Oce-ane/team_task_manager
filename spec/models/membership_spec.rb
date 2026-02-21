# frozen_string_literal: true

require "rails_helper"

RSpec.describe Membership, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:project) }
  end

  describe "validations" do
    subject { create(:membership) }

    it { should validate_uniqueness_of(:user_id).scoped_to(:project_id).with_message("is already a member of this project") }
  end

  describe "enum" do
    it { should define_enum_for(:role).with_values(member: 0, owner: 1) }
  end
end
