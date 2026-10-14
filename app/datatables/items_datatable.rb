class ItemsDatatable < ApplicationDatatable
  private

  def model
    Item
  end

  def columns
    ["id", "generic_part_no", "group", "family", "name", "description", "package", "mop", "assembled", "base_item", "extra_item", "index"]
  end

  def data
    paged_records.map do |item|
      [
        item.id,
        link_to(item.partNo, "/items/#{item.id}"),
        h(item.group),
        h(item.family),
        h(item.name),
        h(item.description),
        h(item.package),
        h(item.mop),
        h(item.assembled),
        h(item.base_item),
        h(item.extra_item),
        h(item.index)
      ]
    end
  end

  def filtered_records
    records = Item.order(:id).where.not(index: 0)
    if params[:search].present? && params[:search][:value].present?
      q = "%#{params[:search][:value]}%"
      records = records.where("items.generic_part_no LIKE :q OR items.name LIKE :q OR items.description LIKE :q", q: q)
    end
    records.order(quoted_sort_column => sort_direction.to_sym)
  end

  # "index" needs quoting in PostgreSQL (reserved word)
  def quoted_sort_column
    col = sort_column
    col == "index" ? "items.#{col.inspect}" : "items.#{col}"
  end
end
