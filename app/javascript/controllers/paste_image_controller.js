import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("paste", this.handlePaste.bind(this))
    console.log("paste_image_controller connected")
  }

  disconnect() {
    this.element.removeEventListener("paste", this.handlePaste.bind(this))
  }

  async handlePaste(event) {
    const items = event.clipboardData?.items

    for (const item of items) {
      if (item.type.indexOf("image") === -1) continue

      event.preventDefault()

      const file = item.getAsFile()
      const formData = new FormData()
      formData.append("image", file)

      try {
        const response = await fetch("/admin/posts/upload_image", {
          method: "POST",
          body: formData,
          headers: {
            "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
          }
        })

        if (!response.ok) throw new Error("上传失败")

        const { markdown } = await response.json()

        const start = this.element.selectionStart
        const end = this.element.selectionEnd
        const text = this.element.value

        this.element.value = text.substring(0, start) + markdown + text.substring(end)
        this.element.selectionStart = this.element.selectionEnd = start + markdown.length

        // 触发 input 事件以确保 Rails 表单能感知到变化
        this.element.dispatchEvent(new Event("input"))
      } catch (error) {
        console.error("图片上传失败:", error)
        alert("图片上传失败，请重试")
      }

      break
    }
  }
}