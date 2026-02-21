class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.integer :role, default: 0, null: false

      t.timestamps
    end

    add_index :memberships, [ :user_id, :project_id ], unique: true
  end
end
