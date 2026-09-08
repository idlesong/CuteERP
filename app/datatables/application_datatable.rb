# Base class for server-side DataTables JSON endpoints.
# Responds with both modern (draw/recordsTotal/recordsFiltered/data)
# and legacy (sEcho/iTotalRecords/iTotalDisplayRecords/aaData) keys so it
# works with any DataTables version.
class ApplicationDatatable
  attr_reader :view

  delegate :params, :link_to, to: :view

  def initialize(view)
    @view = view
  end

  # `h` is private on view contexts, so delegate cannot reach it.
  def h(value)
    ERB::Util.html_escape(value)
  end

  def as_json(*)
    {
      draw: params[:draw].to_i,
      recordsTotal: total_records,
      recordsFiltered: filtered_records.count,
      data: data,
      sEcho: params[:sEcho].to_i,
      iTotalRecords: total_records,
      iTotalDisplayRecords: filtered_records.count,
      aaData: data
    }
  end

  private

  # Subclasses implement: model, columns, filtered_records, data
  def paged_records
    filtered_records.offset(params[:start].to_i).limit(per_page)
  end

  def total_records
    model.count
  end

  def sort_column
    order = params[:order] && params[:order]["0"]
    return columns.first unless order

    columns[order[:column].to_i] || columns.first
  end

  def sort_direction
    order = params[:order] && params[:order]["0"]
    dir = order && order[:dir]
    %w[asc desc].include?(dir) ? dir : "asc"
  end

  def page
    params[:start].to_i / per_page + 1
  end

  def per_page
    length = params[:length].to_i
    length.positive? ? length : 10
  end
end
