class P2PriceDomain < ActiveRecord::Migration[8.1]
  def up
    # ---- prices 重构（D3/D7/D8/D9）----
    add_column :prices, :v1_price, :decimal, precision: 8, scale: 2
    add_column :prices, :v2_price, :decimal, precision: 8, scale: 2
    add_column :prices, :effective_from, :date
    add_column :prices, :expired_at, :date
    add_column :prices, :currency, :string, default: "RMB"

    # 旧 extra_price 数据并入 v1_price（附加价值第一成分）
    execute("UPDATE prices SET v1_price = extra_price WHERE extra_price IS NOT NULL")
    remove_column :prices, :extra_price
    remove_column :prices, :item_id # 报价维度改为通用型号（D7）

    # ---- 阶梯价重设计（D5，替代 set_prices step1..16）----
    create_table :price_list_releases do |t|
      t.date    :released_at, null: false
      t.string  :note
      t.timestamps
    end

    create_table :price_list_entries do |t|
      t.references :release, null: false, foreign_key: { to_table: :price_list_releases }
      t.string  :generic_part_no, null: false
      t.string  :sell_by, null: false, default: "OEM"
      t.integer :min_qty, null: false
      t.decimal :price, precision: 8, scale: 2, null: false
      t.datetime :amended_at
      t.timestamps
    end
    add_index :price_list_entries, [:release_id, :generic_part_no, :sell_by, :min_qty],
              unique: true, name: "idx_pl_entries_lookup"

    # 存量 set_prices → 新模型（best effort，历史测试数据）
    say_with_time "Migrating set_prices into price_list releases/entries" do
      qty_tiers = [1, 1000, 2500, 5000, 10000, 20000, 50000, 100000]
      generics = Item.pluck(:id, :generic_part_no).to_h
      release_ids = {}

      sp_rows = execute("SELECT * FROM set_prices WHERE released_at IS NOT NULL AND item_id IS NOT NULL").to_a
      sp_rows.each do |sp|
        rel_date = sp["released_at"].to_date
        gen = generics[sp["item_id"]]
        next if gen.blank?

        rel_id = release_ids[rel_date] ||= select_value(
          "INSERT INTO price_list_releases (released_at, note, created_at, updated_at) " \
          "VALUES ('#{rel_date}', '迁移自 set_prices', NOW(), NOW()) RETURNING id"
        )

        16.times do |idx|
          step_val = sp["step#{idx + 1}"]
          next if step_val.nil?
          channel = idx < 8 ? "OEM" : "ODM"
          min_qty = qty_tiers[idx % 8]
          execute(
            "INSERT INTO price_list_entries (release_id, generic_part_no, sell_by, min_qty, price, created_at, updated_at) " \
            "VALUES (#{rel_id}, '#{gen.gsub("'", "''")}', '#{channel}', #{min_qty}, #{step_val.to_f}, NOW(), NOW())"
          )
        end
      end
      true
    end

    drop_table :set_prices
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "P2 价格域重构不可逆（set_prices 已被 price_list_* 取代）"
  end
end
