class AddMailerMethodToOnCallReminder < ActiveRecord::Migration
  def change
    add_column :on_call_reminders, :mailer_method, :string, null: false
  end
end
