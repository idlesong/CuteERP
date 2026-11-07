// Excel-style per-column filter row for DataTables instances.
//
// For every column a filter control is generated in an injected <tfoot> row:
//   - enum-like column (few distinct values)  -> select dropdown (exact match)
//   - numeric column                          -> single input "最小~最大" (compact range syntax)
//   - date column                             -> month dropdown (YYYY-MM，Excel 风格)
//   - everything else                         -> text input (contains)
//
// Views may override the heuristic per column with:
//   <th data-filter="select"> / "num" / "date"(=month) / "month" / "daterange" / "text" / "none"

import DataTable from "datatables.net"

const NUM_RE = /^-?\d+(\.\d+)?$/
const DATE_RE = /^\d{4}[-/]\d{1,2}[-/]\d{1,2}/

const escapeRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
const distinctValues = (arr) => [...new Set(arr)]

// stateSave 恢复的列搜索值 → 筛选控件回填显示（去掉 select/month 用正则锚点 ^...$）
function restoredSearch(dt, columnIndex) {
  const s = dt.column(columnIndex).search()
  return typeof s === "string" ? s.replace(/^\^/, "").replace(/\$$/, "") : ""
}

function pruneStaleRangePredicates() {
  DataTable.ext.search = DataTable.ext.search.filter((p) => !p.__table || p.__table.isConnected)
}

// ---- 筛选状态补恢复 ----
// 数值区间（函数式列搜索）与日期区间（ext.search 谓词）DataTables stateSave 无法序列化，
// 整页跳转（快捷编辑等）后会丢。按列登记 get/set：stateSave 时捕获输入值（application.js
// 的 stateSaveCallback 调 captureColumnFilters），重新进页后 init 完成时重放（replayColumnFilters）。
function registerReplay(table, columnIndex, get, set) {
  table.__filterReplay = table.__filterReplay || {}
  table.__filterReplay[columnIndex] = { get, set }
}

export function captureColumnFilters(table) {
  const reg = table.__filterReplay
  if (!reg) return undefined
  const out = []
  Object.keys(reg).forEach((k) => {
    const v = reg[k].get()
    const empty = v == null || v === "" || (Array.isArray(v) && v.every((x) => x == null || x === ""))
    if (!empty) out.push({ i: Number(k), v })
  })
  return out.length ? out : undefined
}

export function replayColumnFilters(table, dt, saved) {
  if (!saved || !saved.length) return
  const reg = table.__filterReplay
  if (!reg) return
  let touched = false
  saved.forEach(({ i, v }) => {
    const entry = reg[i]
    if (!entry) return
    try {
      entry.set(v)
      touched = true
    } catch (e) {
      // 控件不存在（列结构变化），跳过该列
    }
  })
  if (touched) dt.draw() // 统一收尾：区间谓词/函数式搜索在此一并生效
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
  const restored = restoredSearch(dt, columnIndex)
  if (restored) input.value = restored // stateSave 恢复
  th.appendChild(input)
}

function appendSelectFilter(th, dt, columnIndex, values) {
  const select = document.createElement("select")
  select.className = "form-select form-select-sm"
  select.add(new Option("(全部)", ""))
  distinctValues(values).sort().forEach((v) => select.add(new Option(v, v)))
  const restored = restoredSearch(dt, columnIndex)
  if (restored && select.querySelector(`option[value="${CSS.escape(restored)}"]`)) {
    select.value = restored // stateSave 恢复
  }
  select.addEventListener("change", () => {
    if (select.value) {
      dt.column(columnIndex).search("^" + escapeRegex(select.value) + "$", true, false).draw()
    } else {
      dt.column(columnIndex).search("").draw()
    }
  })
  th.appendChild(select)
}

// Excel 式按月筛选：从日期列（YYYY-MM-DD…）提取 YYYY-MM 去重生成下拉
function appendMonthFilter(th, dt, columnIndex) {
  const select = document.createElement("select")
  select.className = "form-select form-select-sm"
  select.add(new Option("(全部月份)", ""))
  const months = distinctValues(
    dt.column(columnIndex).nodes().toArray()
      .map((el) => (el.textContent.trim().match(/^\d{4}-\d{2}/) || [])[0])
      .filter(Boolean)
  ).sort()
  months.forEach((m) => select.add(new Option(m, m)))
  const restored = restoredSearch(dt, columnIndex)
  if (restored && select.querySelector(`option[value="${CSS.escape(restored)}"]`)) {
    select.value = restored // stateSave 恢复
  }
  select.addEventListener("change", () => {
    // 前缀匹配：2026-10 命中 2026-10-19 等（regex=true、smart=false，否则按字面词匹配永不命中）
    dt.column(columnIndex).search(select.value ? "^" + escapeRegex(select.value) : "", true, false).draw()
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
  registerReplay(table, columnIndex,
    () => (from.value || to.value ? [from.value, to.value] : null),
    (v) => {
      const [a, b] = Array.isArray(v) ? v : [v, ""]
      from.value = a == null ? "" : String(a)
      to.value = b == null ? "" : String(b)
    }
  )
}

// 数值列紧凑筛选：单输入框区间语法（Excel 自定义筛选风格）
//   100~500 → 区间；~500 → ≤；100~ → ≥；100 → 精确
// 用 v3 函数式列搜索（column.search(fn)），不走全局 ext.search
function appendNumberFilter(th, dt, columnIndex, table) {
  const input = makeInput("form-control form-control-sm")
  input.placeholder = "100~500"
  const parse = (raw) =>
    raw === "" ? [null, "", "", undefined] : raw.match(/^(-?[\d.]*)~(-?[\d.]*)$|^(-?[\d.]+)$/)
  // 函数式列搜索（search("") 无法覆盖上一个函数式搜索，始终用函数）
  const applySearch = (raw) => {
    const m = parse(raw)
    if (!m) return false // 语法不对不过滤，避免整表清空
    dt.column(columnIndex).search((cellText) => {
      if (raw === "") return true
      const v = parseFloat(String(cellText).replace(/[^\d.-]/g, ""))
      if (isNaN(v)) return false
      if (m[3] !== undefined) return v === parseFloat(m[3]) // 精确
      if (m[1] !== "" && v < parseFloat(m[1])) return false
      if (m[2] !== "" && v > parseFloat(m[2])) return false
      return true
    })
    return true
  }
  let timer = null
  input.addEventListener("input", () => {
    clearTimeout(timer)
    timer = setTimeout(() => {
      if (applySearch(input.value.trim())) dt.draw()
    }, 250)
  })
  // 筛选行在创建表单内：拦截回车，避免误触发创建
  input.addEventListener("keydown", (e) => {
    if (e.key === "Enter") e.preventDefault()
  })
  registerReplay(table, columnIndex,
    () => input.value,
    (v) => {
      input.value = String(v)
      applySearch(String(v).trim()) // draw 由 replayColumnFilters 收尾统一触发
    }
  )
  th.appendChild(input)
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

    if (mode === "month" || mode === "date" ||
        (!mode && nonEmpty.length > 0 && nonEmpty.every((t) => DATE_RE.test(t)))) {
      // 日期列统一用月份下拉（Excel 风格）；要"从/到"区间时显式 data-filter="daterange"
      appendMonthFilter(th, dt, i)
    } else if (mode === "daterange") {
      appendRangeFilter(th, dt, i, table, "date")
    } else if (mode === "select" || (!mode && nonEmpty.length > 0 && distinctValues(nonEmpty).length <= 10)) {
      appendSelectFilter(th, dt, i, nonEmpty)
    } else if (mode === "num" || (!mode && nonEmpty.length > 0 && nonEmpty.every((t) => NUM_RE.test(t)))) {
      appendNumberFilter(th, dt, i, table)
    } else {
      appendTextFilter(th, dt, i)
    }
  }
}
