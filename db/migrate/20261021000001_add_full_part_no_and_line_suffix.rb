class AddFullPartNoAndLineSuffix < ActiveRecord::Migration[8.1]
  def change
    # 客户所订完整型号（如 SCT3089DVM）；generic_part_no 由命名规则派生并保留（聚合查询用）
    add_column :order_lines, :full_part_no, :string
    # 六联单转产定型后缀（1 字符，集合在用户设置 naming.suffixes；缺省=nil）
    add_column :production_lines, :suffix, :string
    OrderLine.reset_column_information
    ProductionLine.reset_column_information
    # 存量订单行本就按通用型号录入：full = generic 一次性回填
    OrderLine.update_all("full_part_no = generic_part_no")
  end
end
