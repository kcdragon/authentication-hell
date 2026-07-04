class TotpChallenge
  attr_reader :streak, :entered, :pending_code

  def initialize
    @active = false
    @started = false
    @registered = false
    @streak = 0
    @entered = []
    @pending_code = nil
    @submitting = false
    @complete = false
  end

  def active? = @active

  def started? = @started

  def registered? = @registered

  def submitting? = @submitting

  def complete? = @complete

  def activate! = @active = true

  def deactivate! = @active = false

  def start! = @started = true

  def enter(digit) = @entered << digit

  def submit!
    @pending_code = @entered.join
    @entered = []
    @submitting = true
  end

  def code_taken! = @pending_code = nil

  def submit_resolved! = @submitting = false

  def record_status(data)
    @registered = data["registered"] if data.key?("registered")
    @streak = data["streak"] if data.key?("streak")
    @complete = data["complete"] if data.key?("complete")
  end
end
