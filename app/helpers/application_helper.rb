module ApplicationHelper
  def hidden_div_if(condition, attributes = {}, &block)
    attributes["style"] = "display: none" if condition
    content_tag("div", attributes, &block)
  end

  # 金额格式：¥1,050.00 / $66.00（符号紧跟数字 + 千分位 + 固定 2 位小数）
  def money(amount, currency = "RMB")
    unit = currency == "USD" ? "$" : "¥"
    return "-" if amount.nil?

    "#{unit}#{number_with_precision(amount.to_f, precision: 2, delimiter: ",")}"
  end

  # 客户显示名：中文简称优先，缺省回退英文简称
  def cust_name(customer)
    return "" if customer.nil?

    customer.name_zh.presence || customer.name
  end

  # 计划分节：按客户币别判断美元段（名称可能是中文简称或英文名）
  def usd_customer?(display_name)
    Customer.where("name = :n OR name_zh = :n", n: display_name).order(:id).take&.currency == "USD"
  end

  # 矩阵 {group => {customer显示名 => cells}} 按客户币别拆为条目级两段（而非按大类整组）：
  # 返回 { "人民币" => [[group, 客户显示名, cells], ...], "美元" => [...] }（人民币段在前）
  def split_matrix_by_currency(matrix)
    currencies = Customer.pluck(:name, :name_zh, :currency)
                         .each_with_object({}) do |(name, name_zh, cur), h|
      h[name] = cur if name.present?
      h[name_zh] = cur if name_zh.present?
    end
    sections = { "人民币" => [], "美元" => [] }
    matrix.each do |group, customers|
      customers.each do |cname, cells|
        sections[currencies[cname] == "USD" ? "美元" : "人民币"] << [group, cname, cells]
      end
    end
    sections
  end

  def find_order_number_from_reference(refer_line_id)
    OrderLine.find(refer_line_id)&.order&.po_number
  end

  def markdown(content)
    Kramdown::Document.new(content, autolink: true).to_html
  end

  # best_in_place replacement: a clickable value edited in place via
  # the inline-edit Stimulus controller.
  def inline_edit(record, attribute, type: :input, collection: nil)
    value = record.public_send(attribute)
    display = value.to_s
    if collection
      pair = collection.find { |v, _label| v.to_s == value.to_s }
      display = pair ? pair[1] : display
    end

    data = {
      controller: "inline-edit",
      action: "click->inline-edit#edit",
      inline_edit_url_value: polymorphic_path(record),
      inline_edit_param_value: record.model_name.singular,
      inline_edit_attribute_value: attribute.to_s,
      inline_edit_type_value: type.to_s,
      value: value
    }
    data[:inline_edit_collection_value] = collection if collection

    content_tag :span, display, data: data,
                                class: "inline-edit text-primary",
                                style: "cursor: pointer; border-bottom: 1px dashed #6ea8fe;"
  end
end
