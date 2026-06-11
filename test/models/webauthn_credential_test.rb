require "test_helper"

class WebauthnCredentialTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test "valid with an external_id, public_key, and nickname" do
    credential = @user.webauthn_credentials.build(external_id: "ext", public_key: "key", nickname: "Laptop")
    assert credential.valid?
  end

  test "external_id is required and globally unique" do
    @user.webauthn_credentials.create!(external_id: "dup", public_key: "key", nickname: "One")
    other = users(:two).webauthn_credentials.build(external_id: "dup", public_key: "key", nickname: "Two")

    assert_not other.valid?
    assert other.errors[:external_id].any?
  end

  test "nickname defaults to Passkey when blank" do
    credential = @user.webauthn_credentials.create!(external_id: "ext", public_key: "key", nickname: " ")
    assert_equal "Passkey", credential.nickname
  end
end
