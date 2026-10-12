// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"

import jquery from "jquery"
window.$ = jquery
window.jQuery = jquery

import * as Bootstrap from "bootstrap"
window.Bootstrap = Bootstrap

import "datatables.net"
import "datatables.net-bs5"

import "./controllers"

document.addEventListener("turbo:load", () => {
  // Bootstrap tooltips
  document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach((el) => new Bootstrap.Tooltip(el))

  // DataTables (legacy markup uses .datatable)
  document.querySelectorAll(".datatable").forEach((table) => {
    if (!$.fn.DataTable.isDataTable(table)) {
      $(table).DataTable({
        pageLength: 50,
        order: [[1, "asc"]]
      })
    }
  })

  // ship status modal: point its form at the selected sales order
  $(".shipLink").on("click", function () {
    const orderId = $(this).data("id")
    $(".modal-body #ship_status").attr("action", "/sales_orders/" + orderId)
  })

  // quick "new" buttons: POST a minimal JSON payload then reload
  $(".ajax-new").on("click", function () {
    const newUrl = $(this).attr("id")
    const attrData = $(this).attr("data")
    const attrData2 = $(this).attr("data-2")

    let objData
    switch (newUrl) {
      case "/items":
        objData = { item: { name: "new", imageURL: "rails.png", partNo: "unknown", price: 0.01 } }
        break
      case "/contacts":
        objData = { contact: { name: "new", customer_id: attrData } }
        break
      case "/customers":
        objData = { customer: { name: "new" } }
        break
      case "/opportunities":
        objData = { opportunity: { note: "new", priority: "201", project_type: "数字对讲类", customer_id: attrData } }
        break
      case "/oppostatuses":
        objData = { oppostatus: { status: "new", opportunity_id: attrData, user_id: attrData2 } }
        break
      default:
        return
    }

    $.ajax({
      type: "POST",
      url: newUrl,
      data: objData,
      dataType: "json",
      success: () => {
        window.location.reload()
      },
      error: () => {
        alert("Error occured")
      }
    })
  })
})
