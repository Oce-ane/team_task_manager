# frozen_string_literal: true

require "rails_helper"

RSpec.describe Project, type: :model do
  describe "associations" do
    it { should have_many(:memberships).dependent(:destroy) }
    it { should have_many(:members).through(:memberships).source(:user) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
  end
end
