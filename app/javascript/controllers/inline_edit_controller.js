import { Controller } from "@hotwired/stimulus"

// Replaces the old best_in_place gem: click a value to edit it in place.
// blur/Enter saves via fetch PATCH, Escape cancels.
export default class extends Controller {
  static values = { url: String, param: String, attribute: String, type: String, collection: Array }

  edit(event) {
    if (this.editing) return
    this.editing = true
    this.originalHTML = this.element.innerHTML
    const currentValue = this.element.dataset.value ?? this.element.textContent.trim()

    let field
    if (this.typeValue === "select") {
      field = document.createElement("select")
      field.className = "form-select form-select-sm d-inline-block"
      this.collectionValue.forEach(([v, label]) => {
        const opt = document.createElement("option")
        opt.value = v
        opt.textContent = label
        if (String(v) === String(currentValue)) opt.selected = true
        field.appendChild(opt)
      })
    } else {
      field = document.createElement("input")
      field.type = "text"
      field.value = currentValue
      field.className = "form-control form-control-sm d-inline-block"
      field.style.width = "10rem"
    }

    this.element.innerHTML = ""
    this.element.appendChild(field)
    field.focus()
    if (field.select) field.select()

    const save = () => {
      const value = field.value
      if (String(value) === String(currentValue)) {
        this.cancel()
        this.editing = false
        return
      }
      const body = new URLSearchParams()
      body.append(`${this.paramValue}[${this.attributeValue}]`, value)
      fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: body
      })
        .then((resp) => {
          if (resp.ok) {
            this.display(value)
          } else {
            this.cancel()
          }
          this.editing = false
        })
        .catch(() => {
          this.cancel()
          this.editing = false
        })
    }

    field.addEventListener("blur", save, { once: true })
    field.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault()
        field.blur()
      } else if (e.key === "Escape") {
        field.removeEventListener("blur", save)
        this.cancel()
        this.editing = false
      }
    })
  }

  display(value) {
    if (this.typeValue === "select") {
      const match = this.collectionValue.find(([v]) => String(v) === String(value))
      this.element.textContent = match ? match[1] : value
    } else {
      this.element.textContent = value
    }
    this.element.dataset.value = value
  }

  cancel() {
    this.element.innerHTML = this.originalHTML
  }
}
