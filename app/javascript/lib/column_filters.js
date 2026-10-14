// Excel-style per-column filter row for DataTables instances.
//
// For every column a filter control is generated in an injected <tfoot> row:
//   - enum-like column (few distinct values)  -> select dropdown (exact match)
//   - numeric column                          -> number range (从/到)
//   - date column                             -> date range  (从/到)
//   - everything else                         -> text input (contains)
//
// Views may override the heuristic per column with:
//   <th data-filter="select"> / "num" / "date" / "text" / "none"

import DataTable from "datatables.net"

const NUM_RE = /^-?\d+(\.\d+)?$/
const DATE_RE = /^\d{4}[-/]\d{1,2}[-/]\d{1,2}/

const escapeRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
const distinctValues = (arr) => [...new Set(arr)]

function pruneStaleRangePredicates() {
  DataTable.ext.search = DataTable.ext.search.filter((p) => !p.__table || p.__table.isConnected)
}

function makeInput(className) {
  const input = document.createElement("input")
  input.className = className
  return input
}

function appendTextFilter(th, dt, columnIndex) {
  const input = makeInput("form-control form-control-sm")
  input.placeholder = "包含..."
  let timer = null
  input.addEventListener("input", () => {
    clearTimeout(timer)
    timer = setTimeout(() => {
      dt.column(columnIndex).search(input.value).draw()
    }, 200)
  })
  // 筛选行在创建表单内：拦截回车，避免误触发创建
  input.addEventListener("keydown", (e) => {
    if (e.key === "Enter") e.preventDefault()
  })
  th.appendChild(input)
}

function appendSelectFilter(th, dt, columnIndex, values) {
  const select = document.createElement("select")
  select.className = "form-select form-select-sm"
  select.add(new Option("(全部)", ""))
  distinctValues(values).sort().forEach((v) => select.add(new Option(v, v)))
  select.addEventListener("change", () => {
    if (select.value) {
      dt.column(columnIndex).search("^" + escapeRegex(select.value) + "$", true, false).draw()
    } else {
      dt.column(columnIndex).search("").draw()
    }
  })
  th.appendChild(select)
}

function appendRangeFilter(th, dt, columnIndex, table, type) {
  const wrap = document.createElement("div")
  wrap.className = "d-flex gap-1"
  const from = makeInput("form-control form-control-sm")
  const to = makeInput("form-control form-control-sm")
  from.type = to.type = type === "date" ? "date" : "number"
  from.placeholder = "从"
  to.placeholder = "到"
  ;[from, to].forEach((el) => {
    el.addEventListener("change", () => dt.draw())
    wrap.appendChild(el)
  })
  th.appendChild(wrap)

  const toValue = (raw) => (type === "date" ? Date.parse(raw) : parseFloat(raw))
  const predicate = (settings, data) => {
    if (settings.nTable !== table) return true // other tables are untouched
    const fromRaw = from.value
    const toRaw = to.value
    if (fromRaw === "" && toRaw === "") return true
    const v = toValue((data[columnIndex] || "").trim())
    if (isNaN(v)) return false
    if (fromRaw !== "" && v < toValue(fromRaw)) return false
    if (toRaw !== "" && v > toValue(toRaw)) return false
    return true
  }
  predicate.__table = table
  pruneStaleRangePredicates()
  DataTable.ext.search.push(predicate)
}

// Attach the filter row to an initialised DataTable.
// The row is inserted into <thead> (below existing header/creation rows),
// so it always sits right under the column titles.
export function initColumnFilters(table, dt) {
  if (table.dataset.columnFilters === "off") return

  const columnCount = dt.columns().count()
  if (columnCount === 0) return
  if (!table.tHead) return

  // remove a previously generated filter row (Turbo cache restore)
  table.querySelectorAll("tr[data-filter-row]").forEach((el) => el.remove())

  const row = document.createElement("tr")
  row.dataset.filterRow = "1"
  table.tHead.appendChild(row)

  const headerCells = table.tHead.rows[0].cells

  for (let i = 0; i < columnCount; i++) {
    const th = document.createElement("th")
    row.appendChild(th)

    const header = headerCells[i]
    const mode = header ? header.dataset.filter : undefined
    if (mode === "none") continue

    // inspect rendered cell text of the whole column
    const cellNodes = dt.column(i).nodes().toArray()
    const texts = cellNodes.map((el) => el.textContent.trim())
    const nonEmpty = texts.filter(Boolean)
    const hasControls = cellNodes.some((el) => el.querySelector("button, input, select, form"))

    if (hasControls && mode === undefined) continue // action/button columns: skip

    if (mode === "select" || (!mode && nonEmpty.length > 0 && distinctValues(nonEmpty).length <= 10)) {
      appendSelectFilter(th, dt, i, nonEmpty)
    } else if (mode === "num" || (!mode && nonEmpty.length > 0 && nonEmpty.every((t) => NUM_RE.test(t)))) {
      appendRangeFilter(th, dt, i, table, "number")
    } else if (mode === "date" || (!mode && nonEmpty.length > 0 && nonEmpty.every((t) => DATE_RE.test(t)))) {
      appendRangeFilter(th, dt, i, table, "date")
    } else {
      appendTextFilter(th, dt, i)
    }
  }
}
