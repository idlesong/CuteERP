// 可搜索下拉（零依赖）：select[data-searchable] 上方注入过滤输入框，按选项文本过滤。
// 保持原生 select 表单值语义不变；适用于选项较多的客户/型号下拉。
// 过滤用 option.hidden 实现，不影响其他 JS 对 select.value 的读写（如自动带出客户）。
export function initSearchableSelects(root = document) {
  root.querySelectorAll("select[data-searchable]").forEach((select) => {
    if (select.dataset.searchableInit) return
    select.dataset.searchableInit = "1"

    const input = document.createElement("input")
    input.type = "search"
    input.className = "form-control form-control-sm mb-1"
    input.placeholder = "输入过滤…"
    input.title = "可打字过滤选项"
    select.before(input)

    const options = Array.from(select.options)
    input.addEventListener("input", () => {
      const q = input.value.trim().toLowerCase()
      options.forEach((opt) => {
        opt.hidden = Boolean(q) && !opt.disabled && !opt.textContent.toLowerCase().includes(q)
      })
    })
    // 过滤框内回车不应触发所在表单提交（如对账单查询/快捷创建）
    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") e.preventDefault()
    })
  })
}
