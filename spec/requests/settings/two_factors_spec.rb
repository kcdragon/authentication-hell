# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings::TwoFactors", type: :request do
  let(:user) { create(:user) }

  before { sign_in_as user }

  describe "GET /settings/two_factor" do
    it "renders successfully when 2FA is off" do
      get settings_two_factor_url
      expect(response).to have_http_status(:success)
    end

    it "renders successfully when 2FA is on" do
      secret = User.generate_otp_secret
      user.update!(otp_secret: secret, otp_enabled_at: Time.current)
      user.generate_recovery_codes!
      user.save!

      get settings_two_factor_url
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /settings/two_factor/new" do
    it "seeds a pending secret and renders the setup page" do
      get new_settings_two_factor_url
      expect(response).to have_http_status(:success)
      expect(session[:pending_otp_secret]).to be_present
    end

    it "redirects when 2FA is already enabled" do
      user.update!(otp_secret: User.generate_otp_secret, otp_enabled_at: Time.current)
      get new_settings_two_factor_url
      expect(response).to redirect_to(settings_two_factor_url)
    end
  end

  describe "POST /settings/two_factor/confirm" do
    context "with a valid code" do
      it "enables 2FA and stores hashed recovery codes" do
        get new_settings_two_factor_url
        secret = session[:pending_otp_secret]
        code = ROTP::TOTP.new(secret).now

        post confirm_settings_two_factor_url, params: {code: code}

        expect(response).to have_http_status(:success)
        user.reload
        expect(user.totp_enabled?).to be(true)
        expect(user.otp_secret).to eq(secret)
        expect(user.otp_recovery_codes.length).to eq(User::RECOVERY_CODE_COUNT)
        expect(session[:pending_otp_secret]).to be_nil
      end
    end

    context "with an invalid code" do
      it "does not enable 2FA and re-renders" do
        get new_settings_two_factor_url
        post confirm_settings_two_factor_url, params: {code: "000000"}
        expect(response).to have_http_status(:success)
        user.reload
        expect(user.totp_enabled?).to be(false)
      end
    end

    context "without a pending secret" do
      it "redirects to setup" do
        post confirm_settings_two_factor_url, params: {code: "123456"}
        expect(response).to redirect_to(new_settings_two_factor_url)
      end
    end
  end

  describe "DELETE /settings/two_factor" do
    before do
      user.update!(otp_secret: User.generate_otp_secret, otp_enabled_at: Time.current)
      user.generate_recovery_codes!
      user.save!
    end

    context "with the correct password" do
      it "disables 2FA" do
        delete settings_two_factor_url, params: {password_challenge: "Secret1*3*5*"}
        expect(response).to redirect_to(settings_two_factor_url)
        expect(user.reload.totp_enabled?).to be(false)
      end
    end

    context "with an incorrect password" do
      it "leaves 2FA in place" do
        delete settings_two_factor_url, params: {password_challenge: "wrong"}
        expect(response).to redirect_to(settings_two_factor_url)
        expect(user.reload.totp_enabled?).to be(true)
        expect(session[:inertia_errors]).to include(:password_challenge)
      end
    end
  end
end
