# frozen_string_literal: true

require "rails_helper"

RSpec.describe JwtService do
  let(:payload) { { user_id: 42 } }

  describe ".encode" do
    it "returns a JWT string" do
      token = described_class.encode(payload)
      expect(token).to be_a(String)
      expect(token.split(".").length).to eq(3)
    end

    it "embeds an expiry claim" do
      token = described_class.encode(payload)
      decoded = described_class.decode(token)
      expect(decoded[:exp]).to be_present
    end

    it "accepts a custom expiry" do
      expiry = 1.hour.from_now
      token = described_class.encode(payload, expiry)
      decoded = described_class.decode(token)
      expect(decoded[:exp]).to be_within(5).of(expiry.to_i)
    end
  end

  describe ".decode" do
    it "returns the original payload" do
      token = described_class.encode(payload)
      decoded = described_class.decode(token)
      expect(decoded[:user_id]).to eq(42)
    end

    it "returns a HashWithIndifferentAccess" do
      token = described_class.encode(payload)
      decoded = described_class.decode(token)
      expect(decoded["user_id"]).to eq(decoded[:user_id])
    end

    it "raises JWT::DecodeError for a tampered token" do
      token = described_class.encode(payload)
      tampered = "#{token}garbage"
      expect { described_class.decode(tampered) }.to raise_error(JWT::DecodeError)
    end

    it "raises JWT::DecodeError for an expired token" do
      token = described_class.encode(payload, 1.second.ago)
      expect { described_class.decode(token) }.to raise_error(JWT::DecodeError, "Token has expired")
    end

    it "raises JWT::DecodeError for a blank token" do
      expect { described_class.decode("") }.to raise_error(JWT::DecodeError)
    end
  end
end
