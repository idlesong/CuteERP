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
import { initColumnFilters, captureColumnFilters, replayColumnFilters } from "./lib/column_filters"

// 快捷编辑行（tr.table-warning）保证可见：筛选/页码恢复后，若该行在别的页码则跳页，
// 并滚动定位。行被筛选过滤掉时（数据变化等）不强行清筛选，只跳过。
function ensureEditRowVisible(table, dt) {
  const tr = table.querySelector("tr.table-warning")
  if (!tr) return
  try {
    const pos = dt.rows({ search: "applied" }).indexes().toArray().indexOf(dt.row(tr).index())
    if (pos < 0) return
    const info = dt.page.info()
    const target = Math.floor(pos / info.length)
    if (info.page !== target) dt.page(target).draw(false) // false：保持滚动位置
    setTimeout(() => tr.scrollIntoView({ block: "center", behavior: "smooth" }), 80)
  } catch (e) {
    // 行节点不在 DT 索引中（结构变化），忽略
  }
}

document.addEventListener("turbo:load", () => {
  // Bootstrap tooltips
  document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach((el) => new Bootstrap.Tooltip(el))

  // DataTables (legacy markup uses .datatable) + Excel-style column filter row
  document.querySelectorAll(".datatable").forEach((table, ti) => {
    if (!DataTable.isDataTable(table)) {
      const columnCount = table.querySelectorAll("thead th").length
      const noPaging = table.dataset.paging === "off" // data-paging="off"：工作台整表直出
      // 状态键稳定性：DataTables v3 给无 id 表自动编号 DataTables_Table_N，N 是模块级
      // 递增计数器——Turbo 路由下 JS 模块跨页面存活，同一页面第二次进入 N 已变大 →
      // stateSave 键（unique_id + pathname）漂移，记忆的筛选/页码失效（快捷编辑往返必丢筛选）。
      // 按「路径 + 表序号」赋稳定 id；v3 键不含 query string，edit_id 参数不影响命中。
      if (!table.id) {
        table.id = `dt${location.pathname.replace(/[^a-zA-Z0-9]+/g, "-")}-${ti}`
      }
      let savedFilters // 数值/日期区间筛选：DataTables 自身不序列化，靠 capture/replay 补恢复
      const dt = new DataTable(table, {
        pageLength: 50,
        paging: !noPaging,
        lengthChange: !noPaging, // v3 中 paging:false 仍会显示每页条数下拉，须一并关掉
        info: !noPaging,
        orderCellsTop: true, // 排序绑定第一行标题；第二行=快速创建，第三行=筛选
        order: [[0, "asc"]], // 默认首列升序
        // 持久化排序/分页/列筛选（字符串类）到 localStorage：快捷编辑整页跳转回来后
        // 仍回到原筛选/原页码，行不「消失」
        stateSave: true,
        stateDuration: 8 * 3600, // 工作时段内有效（默认 2 小时太短）
        // 键与 v3 默认完全一致（unique_id + pathname）；额外把区间筛选输入值塞进状态
        stateSaveCallback: (settings, data) => {
          try {
            data.__colFilter = captureColumnFilters(table)
            ;(settings.stateDuration === -1 ? sessionStorage : localStorage)
              .setItem("DataTables_" + settings.unique + "_" + location.pathname, JSON.stringify(data))
          } catch (e) {
            // 存储满/禁用：与 v3 默认一致，静默
          }
        },
        stateLoadCallback: (settings) => {
          try {
            const raw = (settings.stateDuration === -1 ? sessionStorage : localStorage)
              .getItem("DataTables_" + settings.unique + "_" + location.pathname)
            const state = raw ? JSON.parse(raw) : {}
            savedFilters = state.__colFilter
            return state
          } catch (e) {
            return {}
          }
        }
      })
      initColumnFilters(table, dt)
      replayColumnFilters(table, dt, savedFilters)
      ensureEditRowVisible(table, dt)
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
