class AddStateToRequests < ActiveRecord::Migration
  def change
    Request.transaction do
      add_column :requests, :state, :integer
    
      Request.all.each do |r|
        r.state = if r.fulfilled
          :fulfilled
        elsif r.fulfilling_user
          :'offer pending'
        else
          :'seeking offers'
        end
        r.save
      end

      change_column :requests, :state, :integer, null: false
      remove_column :requests, :fulfilled
    end
  end
end
