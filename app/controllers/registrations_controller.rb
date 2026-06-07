class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      ConfirmationsMailer.confirm(@user).deliver_later
      redirect_to new_session_path, notice: "Account created. Check your email to confirm before signing in."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def registration_params
      params.expect(user: [ :username, :email_address, :password, :password_confirmation ])
    end
end
