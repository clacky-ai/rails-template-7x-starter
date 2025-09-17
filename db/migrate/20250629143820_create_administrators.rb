class CreateAdministrators < ActiveRecord::Migration[7.2]
  def change
    create_table :administrators do |t|
      t.string :name, null: false
      t.string :password_digest
      t.string :role, null: false
      t.boolean :first_login, default: true

      t.timestamps
    end
    add_index :administrators, :name, unique: true
    add_index :administrators, :role
  end
end
