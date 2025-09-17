class CreateAdminOplogs < ActiveRecord::Migration[7.2]
  def change
    create_table :admin_oplogs do |t|
      t.references :administrator, null: false, foreign_key: true
      t.string :action
      t.string :resource_type
      t.integer :resource_id
      t.string :ip_address
      t.text :user_agent
      t.text :details

      t.timestamps
    end

    add_index :admin_oplogs, :action
    add_index :admin_oplogs, [:resource_type, :resource_id]
    add_index :admin_oplogs, :created_at
  end
end
