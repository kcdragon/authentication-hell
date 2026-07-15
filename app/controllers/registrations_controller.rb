class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    @user = User.new
  end

  def create
    return redirect_to_confirmation_pending if honeypot_caught?

    @user = User.new(registration_params)

    if @user.save
      ConfirmationsMailer.confirm(@user).deliver_later
      redirect_to_confirmation_pending(@user.email_address)
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def redirect_to_confirmation_pending(email_address = nil)
      session[:pending_confirmation_email] = email_address
      redirect_to confirmation_pending_path
    end

    def registration_params
      params.expect(user: [ :username, :email_address, :password, :password_confirmation ])
    end

    # Bots fill the hidden :nickname field; the fake success gives them no signal to adapt.
    def honeypot_caught?
      params[:nickname].present?
    end
end
