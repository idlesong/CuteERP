class Oppostatus < ActiveRecord::Base
  attr_accessible :issue, :status, :opportunity_id, :todo_description,
  :todo_status, :user_id, :status_mark
  belongs_to :opportunity
  belongs_to :user

  STATUS_LABEL = [["EV","EV"], ["DIN","DIN"], ["DWIN","DWIN"], ["PP","PP"], ["MP","MP"], ["OVER","OVER"]]
  STATUS_FLAG = ["wait", "doing", "done", "drop"]

  #validates :user_id, :presence => true
end
