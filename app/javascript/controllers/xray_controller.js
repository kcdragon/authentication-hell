import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "game:xray"
const TOGGLE_KEY = "x"

const REGIONS = {
  dragonruby: {
    label: "DragonRuby · WASM canvas",
    fill: "rgba(20, 184, 166, 0.28)",
    chip: "rgb(13, 148, 136)",
  },
  rails: {
    label: "Rails",
    fill: "rgba(204, 0, 0, 0.22)",
    chip: "rgb(204, 0, 0)",
  },
}

export default class extends Controller {
  connect() {
    this.boxes = new Map()
    this.onKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.onKeydown)

    if (this.requestedInUrl() || localStorage.getItem(STORAGE_KEY) === "true") {
      this.enable()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    this.disable()
  }

  requestedInUrl() {
    return new URLSearchParams(location.search).get("xray") === "1"
  }

  handleKeydown(event) {
    if (event.key !== TOGGLE_KEY || event.metaKey || event.ctrlKey || event.altKey) return
    if (this.isTyping(event.target)) return
    event.preventDefault()
    this.toggle()
  }

  isTyping(target) {
    if (!target) return false
    const tag = target.tagName
    return tag === "INPUT" || tag === "TEXTAREA" || target.isContentEditable
  }

  toggle() {
    this.enabled ? this.disable() : this.enable()
  }

  enable() {
    if (this.enabled) return
    this.enabled = true
    localStorage.setItem(STORAGE_KEY, "true")

    this.layer = document.createElement("div")
    this.layer.style.cssText =
      "position:fixed;inset:0;pointer-events:none;z-index:2147483000;"
    document.body.appendChild(this.layer)

    this.tick = this.tick.bind(this)
    this.frame = requestAnimationFrame(this.tick)
  }

  disable() {
    if (!this.enabled) return
    this.enabled = false
    localStorage.setItem(STORAGE_KEY, "false")

    cancelAnimationFrame(this.frame)
    this.boxes.clear()
    this.layer?.remove()
    this.layer = null
  }

  tick() {
    const seen = new Set()

    document.querySelectorAll("[data-xray-region]").forEach((source) => {
      const region = REGIONS[source.dataset.xrayRegion]
      if (!region) return

      const rect = source.getBoundingClientRect()
      if (rect.width === 0 || rect.height === 0) return

      seen.add(source)
      const box = this.boxFor(source, region)
      box.style.left = `${rect.left}px`
      box.style.top = `${rect.top}px`
      box.style.width = `${rect.width}px`
      box.style.height = `${rect.height}px`
    })

    this.boxes.forEach((box, source) => {
      if (seen.has(source)) return
      box.remove()
      this.boxes.delete(source)
    })

    this.frame = requestAnimationFrame(this.tick)
  }

  boxFor(source, region) {
    let box = this.boxes.get(source)
    if (box) return box

    box = document.createElement("div")
    box.style.cssText =
      `position:absolute;box-sizing:border-box;background:${region.fill};` +
      `border:2px solid ${region.chip};`

    const chip = document.createElement("span")
    chip.textContent = region.label
    chip.style.cssText =
      `position:absolute;left:0;top:0;background:${region.chip};color:#fff;` +
      "font-family:'Space Mono',ui-monospace,monospace;font-size:22px;" +
      "font-weight:700;letter-spacing:0.05em;text-transform:uppercase;" +
      "padding:4px 12px;white-space:nowrap;"
    box.appendChild(chip)

    this.layer.appendChild(box)
    this.boxes.set(source, box)
    return box
  }
}
