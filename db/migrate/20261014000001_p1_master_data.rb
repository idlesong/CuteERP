class P1MasterData < ActiveRecord::Migration[8.1]
  def up
    # 汇率表（多币种基础，D9）
    create_table :exchange_rates do |t|
      t.date    :month, null: false
      t.string  :currency, null: false, default: "USD"
      t.decimal :rate, precision: 10, scale: 4, null: false
      t.timestamps
    end
    add_index :exchange_rates, [:month, :currency], unique: true

    # 客户：中文名 + 发票三件套
    add_column :customers, :name_zh, :string
    add_column :customers, :invoice_address, :text
    add_column :customers, :invoice_contact, :string
    add_column :customers, :invoice_phone, :string

    # 产品：通用型号化（D4）+ 主数据补全
    add_column :items, :generic_part_no, :string
    add_column :items, :suffix, :string
    add_column :items, :name_zh, :string
    add_column :items, :extra_item2, :string
    add_column :items, :eol_at, :date

    say_with_time "Splitting partNo into generic_part_no + suffix" do
      conflicts = []
      Item.reset_column_information
      Item.find_each do |item|
        pn = item.read_attribute(:partNo).to_s.strip  # 旧列，非派生方法
        next if pn.empty?
        base, sfx = Item.split_part_no(pn)
        item.generic_part_no = base
        item.suffix = sfx
        if Item.exists?(generic_part_no: base, suffix: sfx)
          conflicts << "items##{item.id} #{pn}"
        else
          item.save!(validate: false)
        end
      end
      conflicts.each { |c| say "CONFLICT needs review: #{c}" }
      conflicts.empty?
    end

    # 从旧 User settings 迁移当月汇率（best effort）
    say_with_time "Seeding exchange rate from legacy settings" do
      row = execute("SELECT value FROM settings WHERE var = 'exchange_rate' ORDER BY id LIMIT 1").to_a.first
      raw = row && row["value"]
      parsed = begin
        v = JSON.parse(raw)
        v.is_a?(Hash) ? v["current_month"] : raw
      rescue StandardError
        raw
      end
      r = parsed.to_f
      if r.positive?
        execute("INSERT INTO exchange_rates (month, currency, rate, created_at, updated_at)
                 VALUES ('#{Date.current.beginning_of_month}', 'USD', #{r}, NOW(), NOW())")
      end
      true
    end

    change_column_null :items, :generic_part_no, false
    add_index :items, :generic_part_no
    add_index :items, [:generic_part_no, :suffix], unique: true, nulls_not_distinct: true

    remove_column :items, :partNo
  end

  def down
    add_column :items, :partNo, :string
    execute("UPDATE items SET \"partNo\" = generic_part_no || COALESCE(suffix, '')")
    change_column_null :items, :partNo, false
    remove_index :items, [:generic_part_no, :suffix]
    remove_index :items, :generic_part_no
    remove_column :items, :generic_part_no
    remove_column :items, :suffix
    remove_column :items, :name_zh
    remove_column :items, :extra_item2
    remove_column :items, :eol_at
    remove_column :customers, :name_zh
    remove_column :customers, :invoice_address
    remove_column :customers, :invoice_contact
    remove_column :customers, :invoice_phone
    drop_table :exchange_rates
  end
end
