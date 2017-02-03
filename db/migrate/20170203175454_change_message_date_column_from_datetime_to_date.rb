class ChangeMessageDateColumnFromDatetimeToDate < ActiveRecord::Migration
  def change
    rename_column :messages, :date, :old_date
    add_column :messages, :date, :date

    Message.transaction do
      Message.all.each do |m|
        m.date = m.old_date.to_date
        m.save(validate: false)
      end
    end

    change_column :messages, :date, :date, null: false
    remove_column :messages, :old_date
  end
end
