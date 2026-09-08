class CustomersDatatable < ApplicationDatatable
  private

  def model
    Customer
  end

  def columns
    ["id", "territory", "name", "full_name", "sales_type", "payment", "currency", "since", "credit"]
  end

  def data
    paged_records.map do |customer|
      [
        customer.id,
        h(customer.territory),
        link_to(customer.name, "/customers/#{customer.id}"),
        h(customer.full_name),
        h(customer.sales_type),
        h(customer.disty&.name),
        h(customer.payment),
        h(customer.currency),
        h(customer.since),
        h(customer.credit.to_i)
      ]
    end
  end

  def filtered_records
    records = Customer.includes(:disty).all
    if params[:search].present? && params[:search][:value].present?
      q = "%#{params[:search][:value]}%"
      records = records.where("customers.name LIKE :q OR customers.full_name LIKE :q OR customers.territory LIKE :q", q: q)
    end
    records.order("customers.#{sort_column} #{sort_direction}")
  end
end
