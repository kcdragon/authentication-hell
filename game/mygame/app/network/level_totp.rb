class Network::LevelTotp
  POLL_INTERVAL = 30

  def initialize(challenge)
    @challenge = challenge
    @start = Network::OneShot.new
    @submit = Network::OneShot.new
    @status = Network::Poller.new(url("status"), interval: POLL_INTERVAL)
  end

  def poll(tick)
    return unless @challenge.active?

    unless @challenge.started?
      @start.post(url("start"))
      @challenge.start!
    end
    @start.update

    # Code in the query string, not the body: DR.http_post sends a Hash body as
    # multipart, which Rails won't parse under our urlencoded header.
    if @challenge.pending_code && !@submit.pending?
      @submit.post("#{url("submit")}?code=#{@challenge.pending_code}")
      @challenge.code_taken!
    end
    @submit.update do |data|
      @challenge.record_status(data) if data
      @challenge.submit_resolved!
    end

    @status.poll(tick) { |data| @challenge.record_status(data) }
  end

  private

  def url(action) = "#{Network.server_base}/games/level_totp/#{action}"
end
