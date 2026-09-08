class AddPostIdToAttachments < ActiveRecord::Migration[8.1]
  def change
    add_reference :attachments, :post, foreign_key: true
  end
end
