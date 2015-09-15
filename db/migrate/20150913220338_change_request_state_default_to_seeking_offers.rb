class ChangeRequestStateDefaultToSeekingOffers < ActiveRecord::Migration
  def change
    change_column_default :requests, :state, Request.states[:seeking_offers]
  end
end
