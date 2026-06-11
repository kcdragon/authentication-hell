class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  SIGNUP_NOTICE = "Account created. Check your email to confirm before signing in."

  def new
    @user = User.new
  end

  def create
    return redirect_to(new_session_path, notice: SIGNUP_NOTICE) if honeypot_caught?

    @user = User.new(registration_params)

    if @user.save
      ConfirmationsMailer.confirm(@user).deliver_later
      redirect_to new_session_path, notice: SIGNUP_NOTICE
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def registration_params
      params.expect(user: [ :username, :email_address, :password, :password_confirmation ])
    end

    # Bots fill the hidden :nickname field; humans never see it. Drop the signup
    # silently so they get no signal to adapt.
    def honeypot_caught?
      params[:nickname].present?
    end
end
