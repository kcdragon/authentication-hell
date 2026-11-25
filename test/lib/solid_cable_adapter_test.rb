require "test_helper"
require "action_cable/subscription_adapter/solid_cable"

class SolidCableAdapterTest < ActiveSupport::TestCase
  test "subscribing to a stream through the solid_cable adapter confirms the subscription" do
    adapter = ActionCable::SubscriptionAdapter::SolidCable.new(ActionCable.server)
    confirmed = false

    with_in_memory_listener do
      adapter.subscribe("some_stream", ->(_message) { }, -> { confirmed = true })
    end

    assert confirmed
  end

  private
    def with_in_memory_listener
      listener_class = ActionCable::SubscriptionAdapter::SolidCable::Listener
      subscriber_map = ActionCable::SubscriptionAdapter::SubscriberMap.new
      listener_class.define_singleton_method(:new) { |*| subscriber_map }
      yield
    ensure
      listener_class.singleton_class.remove_method :new
    end
end
