class AddSha256AndStatusToImports < ActiveRecord::Migration[8.1]
  def change
    add_column :imports, :sha256, :string
    add_column :imports, :status, :string, default: "applied" # 存量批次视为已应用
    add_index :imports, :sha256
  end
end
