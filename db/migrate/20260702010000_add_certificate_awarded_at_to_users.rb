class AddCertificateAwardedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :certificate_awarded_at, :datetime
  end
end
