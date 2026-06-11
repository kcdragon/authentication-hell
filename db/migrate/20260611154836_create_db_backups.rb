class CreateDbBackups < ActiveRecord::Migration[8.1]
  def change
    create_table :db_backups do |t|
      t.string :key
      t.datetime :occurred_at

      t.timestamps
    end
  end
end
