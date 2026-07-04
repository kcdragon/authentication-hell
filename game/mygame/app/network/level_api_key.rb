class Network::LevelApiKey
  POLL_INTERVAL = 30

  def initialize(level)
    @level = level
    @start = Network::OneShot.new
    @status = Network::Poller.new(url("status"), interval: POLL_INTERVAL)
    @started = false
    @opened = false
  end

  def poll(tick)
    return if @opened

    unless @started
      @start.post(url("start"))
      @started = true
    end
    @start.update

    @status.poll(tick) do |data|
      if data["opened"]
        @opened = true
        @level.open_bridge!
      end
    end
  end

  private

  def url(action) = "#{Network.server_base}/games/level_api_key/#{action}"
end
