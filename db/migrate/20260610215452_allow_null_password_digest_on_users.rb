class AllowNullPasswordDigestOnUsers < ActiveRecord::Migration[8.1]
  # Passwords become optional: a user may authenticate with a passkey alone.
  def change
    change_column_null :users, :password_digest, true
  end
end
