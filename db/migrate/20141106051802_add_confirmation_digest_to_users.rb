class AddConfirmationDigestToUsers < ActiveRecord::Migration
  def change
    add_column :users, :confirmation_digest, :string
    add_column :users, :confirmed, :boolean, default: false
  end
end
