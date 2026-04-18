# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  let(:user) { create(:user) }

  describe "#totp_enabled?" do
    it "is false when otp_enabled_at is blank" do
      expect(user.totp_enabled?).to be(false)
    end

    it "is true once otp_enabled_at is set" do
      user.update!(otp_enabled_at: Time.current)
      expect(user.totp_enabled?).to be(true)
    end
  end

  describe "#verify_otp" do
    let(:secret) { User.generate_otp_secret }

    it "accepts a valid current code" do
      code = ROTP::TOTP.new(secret).now
      expect(user.verify_otp(code, secret: secret)).to be(true)
    end

    it "rejects a wrong code" do
      expect(user.verify_otp("000000", secret: secret)).to be(false)
    end

    it "rejects blank inputs" do
      expect(user.verify_otp("", secret: secret)).to be(false)
      expect(user.verify_otp("123456", secret: "")).to be(false)
    end
  end

  describe "#generate_recovery_codes!" do
    it "produces ten formatted codes and stores their hashes" do
      codes = user.generate_recovery_codes!
      expect(codes.length).to eq(User::RECOVERY_CODE_COUNT)
      codes.each { |c| expect(c).to match(/\A[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{2}\z/) }
      expect(user.otp_recovery_codes.length).to eq(User::RECOVERY_CODE_COUNT)
      expect(user.otp_recovery_codes).not_to include(*codes)
    end
  end

  describe "#consume_recovery_code!" do
    it "removes only the matching hashed code" do
      codes = user.generate_recovery_codes!
      user.save!

      expect(user.consume_recovery_code!(codes.first)).to be(true)
      user.reload
      expect(user.otp_recovery_codes.length).to eq(User::RECOVERY_CODE_COUNT - 1)
      expect(user.consume_recovery_code!(codes.first)).to be(false)
      expect(user.consume_recovery_code!(codes.last)).to be(true)
    end

    it "returns false for unknown codes" do
      user.generate_recovery_codes!
      user.save!
      expect(user.consume_recovery_code!("DEAD-BEEF-00")).to be(false)
    end
  end

  describe "#disable_two_factor!" do
    it "clears otp state" do
      user.otp_secret = User.generate_otp_secret
      user.otp_enabled_at = Time.current
      user.generate_recovery_codes!
      user.save!

      user.disable_two_factor!
      expect(user.otp_secret).to be_nil
      expect(user.otp_enabled_at).to be_nil
      expect(user.otp_recovery_codes).to eq([])
    end
  end
end
