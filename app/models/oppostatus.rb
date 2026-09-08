class Oppostatus < ActiveRecord::Base
  belongs_to :opportunity
  belongs_to :user

  STATUS_LABEL = [["EV", "EV"], ["DIN", "DIN"], ["DWIN", "DWIN"], ["PP", "PP"], ["MP", "MP"], ["OVER", "OVER"]]
  STATUS_FLAG = [["wait", "wait"], ["doing", "doing"], ["done", "done"], ["drop", "drop"]]

  # validates :user_id, presence: true
end
