import { Controller } from "@hotwired/stimulus"
import { marked } from "marked"

// 设置 marked 选项，启用 GFM（GitHub Flavored Markdown）
marked.setOptions({
  gfm: true,
  breaks: true,
  sanitize: false
})

export default class extends Controller {
  static targets = ["editor", "preview", "editorTab", "previewTab"]

  connect() {
    this.updatePreview()
    this.switchToEditor()
  }

  updatePreview() {
    const markdown = this.editorTarget.value
    const html = marked(markdown)
    this.previewTarget.innerHTML = html
  }

  switchToEditor() {
    this.editorTarget.classList.remove("hidden")
    this.previewTarget.classList.add("hidden")

    this.editorTabTarget.classList.add("text-blue-600", "border-blue-600")
    this.editorTabTarget.classList.remove("text-gray-500", "border-transparent")

    this.previewTabTarget.classList.remove("text-blue-600", "border-blue-600")
    this.previewTabTarget.classList.add("text-gray-500", "border-transparent")
  }

  switchToPreview() {
    this.updatePreview()
    this.editorTarget.classList.add("hidden")
    this.previewTarget.classList.remove("hidden")

    this.previewTabTarget.classList.add("text-blue-600", "border-blue-600")
    this.previewTabTarget.classList.remove("text-gray-500", "border-transparent")

    this.editorTabTarget.classList.remove("text-blue-600", "border-blue-600")
    this.editorTabTarget.classList.add("text-gray-500", "border-transparent")
  }
}