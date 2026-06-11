class CreateWebauthnCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :webauthn_credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :external_id, null: false   # base64url credential id from the authenticator
      t.string  :public_key,  null: false   # COSE public key, serialized by the webauthn gem
      t.bigint  :sign_count,  null: false, default: 0
      t.string  :nickname,    null: false
      t.datetime :last_used_at

      t.timestamps
    end

    # Globally unique: usernameless login looks a credential up before it knows the user.
    add_index :webauthn_credentials, :external_id, unique: true
  end
end
