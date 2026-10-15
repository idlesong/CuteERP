// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"

import * as jqueryModule from "jquery"
const jquery = jqueryModule.default ?? jqueryModule
window.$ = window.jQuery = jquery

import * as Bootstrap from "bootstrap"
window.Bootstrap = Bootstrap

import DataTable from "datatables.net"
import "datatables.net-bs5"
window.DataTable = DataTable

import "./controllers"
import { initColumnFilters } from "./lib/column_filters"

document.addEventListener("turbo:load", () => {
  // Bootstrap tooltips
  document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach((el) => new Bootstrap.Tooltip(el))

  // DataTables (legacy markup uses .datatable) + Excel-style column filter row
  document.querySelectorAll(".datatable").forEach((table) => {
    if (!DataTable.isDataTable(table)) {
      const columnCount = table.querySelectorAll("thead th").length
      const dt = new DataTable(table, {
        pageLength: 50,
        paging: table.dataset.paging !== "off", // data-paging="off" 关闭分页（仪表盘用）
        orderCellsTop: true, // 排序绑定第一行标题；第二行=快速创建，第三行=筛选
        order: columnCount > 1 ? [[1, "asc"]] : []
      })
      initColumnFilters(table, dt)
    }
  })

  // restore original table markup before Turbo caches the page,
  // so the next visit re-initialises cleanly
  document.addEventListener("turbo:before-cache", () => {
    document.querySelectorAll(".datatable").forEach((table) => {
      if (DataTable.isDataTable(table)) {
        new DataTable(table, { retrieve: true }).destroy()
      }
    })
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
