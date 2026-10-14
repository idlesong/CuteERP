module ApplicationHelper
  def hidden_div_if(condition, attributes = {}, &block)
    attributes["style"] = "display: none" if condition
    content_tag("div", attributes, &block)
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
