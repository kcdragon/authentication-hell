class Games::LevelTotpChallengeController < ApplicationController
  skip_forgery_protection only: %i[ start submit ]

  def status
    challenge = Current.session.temporary_totp_challenge
    payload = {
      registered: challenge&.registered? || false,
      streak: challenge&.streak || 0,
      complete: challenge&.complete? || false
    }
    render json: payload
  end

  def start
    Current.session.temporary_totp_challenge&.destroy
    challenge = Current.session.create_temporary_totp_challenge!(secret: Totp.generate_random_secret)
    broadcast_toast(challenge)
    head :no_content
  end

  def register
    challenge = Current.session.temporary_totp_challenge
    error = "Invalid code. Scan the QR and try again." unless challenge&.register!(params[:code])
    broadcast_dev_code(challenge)
    render turbo_stream: turbo_stream.replace(
      toast_id, partial: "games/level_totp_challenge",
      locals: { user: Current.user, challenge: challenge, error: error }
    )
  end

  def submit
    challenge = Current.session.temporary_totp_challenge
    result = challenge&.submit!(params[:code]) || :incorrect
    broadcast_result_toast(challenge, result)
    update_dev_code(challenge)
    if challenge&.complete?
      Turbo::StreamsChannel.broadcast_remove_to(Current.user, :toasts, target: toast_id)
    end
    render json: { ok: result == :accepted, streak: challenge&.streak || 0,
                   complete: challenge&.complete? || false }
  end

  private

  def broadcast_toast(challenge)
    Turbo::StreamsChannel.broadcast_append_to(
      Current.user, :toasts, target: Game::Toasts::PERMANENT_CONTAINER,
      partial: "games/level_totp_challenge",
      locals: { user: Current.user, challenge: challenge }
    )
  end

  def broadcast_result_toast(challenge, result)
    Turbo::StreamsChannel.broadcast_append_to(
      Current.user, :toasts, target: Game::Toasts::EPHEMERAL_CONTAINER,
      partial: "games/level_totp_result",
      locals: { result: result_toast(challenge, result) }
    )
  end

  def broadcast_dev_code(challenge)
    return unless challenge&.registered? && (code = challenge.next_code)

    Turbo::StreamsChannel.broadcast_append_to(
      Current.user, :toasts, target: Game::Toasts::PERMANENT_CONTAINER,
      partial: "games/level_totp_dev_code",
      locals: { user: Current.user, code: code }
    )
  end

  def update_dev_code(challenge)
    code = challenge&.next_code
    return unless code

    if challenge.complete?
      Turbo::StreamsChannel.broadcast_remove_to(Current.user, :toasts, target: dev_code_toast_id)
    elsif challenge.registered?
      Turbo::StreamsChannel.broadcast_replace_to(
        Current.user, :toasts, target: dev_code_toast_id,
        partial: "games/level_totp_dev_code",
        locals: { user: Current.user, code: code }
      )
    end
  end

  def result_toast(challenge, result)
    id = "level_totp_result_#{SecureRandom.hex(4)}"
    case result
    when :accepted
      remaining = TemporaryTotpChallenge::REQUIRED_STREAK - challenge.streak
      message = remaining.zero? ? "Code accepted — challenge complete!" :
                                  "Code accepted — #{remaining} more in a row to go"
      { id: id, ok: true, message: message }
    when :replay
      { id: id, ok: false, message: "You already used that code — wait for the next one" }
    else
      { id: id, ok: false, message: "Incorrect code — your streak is reset" }
    end
  end

  def toast_id = helpers.level_totp_challenge_toast_id(Current.user)

  def dev_code_toast_id = helpers.level_totp_dev_code_toast_id(Current.user)
end
