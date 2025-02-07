import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor", "fileInput"]

  connect() {
    console.log("paste_image_controller connected")
  }

  handleDragOver(event) {
    event.preventDefault()
    event.stopPropagation()
  }

  async handleDrop(event) {
    event.preventDefault()
    event.stopPropagation()

    const files = event.dataTransfer?.files
    if (!files?.length) return

    for (const file of files) {
      if (!file.type.startsWith('image/')) continue
      await this.uploadImage(file)
    }
  }

  async handlePaste(event) {
    const items = event.clipboardData?.items
    if (!items) return

    for (const item of items) {
      if (item.type.indexOf("image") === -1) continue
      event.preventDefault()
      const file = item.getAsFile()
      await this.uploadImage(file)
    }
  }

  async handleFileSelect(event) {
    const files = event.target.files
    if (!files?.length) return

    for (const file of files) {
      if (!file.type.startsWith('image/')) continue
      await this.uploadImage(file)
    }

    // 清空文件输入框，这样同一个文件可以再次选择
    event.target.value = ''
  }

  async uploadImage(file) {
    const formData = new FormData()
    formData.append("image", file)

    try {
      const response = await fetch("/admin/posts/upload_image", {
        method: "POST",
        body: formData,
        headers: {
          "X-CSRF-Token": document.querySelector("[name='csrf-token']")?.content
        }
      })

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.error || "上传失败")
      }

      const { markdown } = await response.json()
      if (!markdown) throw new Error("服务器返回的数据格式不正确")

      const editor = this.editorTarget
      const start = editor.selectionStart || 0
      const end = editor.selectionEnd || 0
      const text = editor.value || ""

      editor.value = text.substring(0, start) + markdown + text.substring(end)
      editor.selectionStart = editor.selectionEnd = start + markdown.length

      // 触发 input 事件以确保 Rails 表单能感知到变化
      editor.dispatchEvent(new Event("input"))
    } catch (error) {
      console.error("图片上传失败:", error)
      alert("图片上传失败，请重试：" + error.message)
    }
  }
}