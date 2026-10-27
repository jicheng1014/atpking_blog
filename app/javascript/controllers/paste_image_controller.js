import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor", "fileInput", "uploads", "list", "count", "hint", "template", "dialog", "submit"]

  connect() {
    this.uploads = new Set()
    this.uploadQueue = Promise.resolve()
    this.form = this.element.closest("form")
    this.submitButtons = [...this.form.querySelectorAll('input[type="submit"], button[type="submit"]')]
      .filter(button => !button.closest("dialog"))
      .map(button => ({ button, disabled: button.disabled }))
    this.submitLabel = this.hasSubmitTarget ? this.submitTarget.value : null
    this.guardSubmit = event => {
      if (![...this.uploads].some(upload => upload.state !== "uploaded")) return
      event.preventDefault()
      event.stopImmediatePropagation()
      this.hintTarget.focus()
    }
    this.appendUploads = event => {
      if (!this.hasSubmitTarget) return
      const images = [...this.uploads].filter(upload => upload.state === "uploaded").map(upload => upload.markdown)
      event.formData.set(this.editorTarget.name, [this.editorTarget.value, ...images].join("\n\n"))
    }
    this.syncPreviews = () => {
      if (this.hasSubmitTarget) return
      for (const upload of this.uploads) {
        if (upload.state === "uploaded" && !this.editorTarget.value.includes(upload.markdown)) this.removeUpload(upload)
      }
    }
    this.beforeCache = () => this.clearUploads()
    this.form.addEventListener("submit", this.guardSubmit, true)
    this.form.addEventListener("formdata", this.appendUploads)
    this.editorTarget.addEventListener("input", this.syncPreviews)
    document.addEventListener("turbo:before-cache", this.beforeCache)
    this.hintTarget.tabIndex = -1
  }

  disconnect() {
    this.clearUploads()
    this.form.removeEventListener("submit", this.guardSubmit, true)
    this.form.removeEventListener("formdata", this.appendUploads)
    this.editorTarget.removeEventListener("input", this.syncPreviews)
    document.removeEventListener("turbo:before-cache", this.beforeCache)
  }

  handleDragOver(event) {
    if (event.dataTransfer?.types.includes("Files")) event.preventDefault()
  }

  handleDrop(event) {
    const files = [...(event.dataTransfer?.files || [])].filter(file => file.type.startsWith("image/"))
    if (!files.length) return
    event.preventDefault()
    this.uploadFiles(files)
  }

  handlePaste(event) {
    const files = [...(event.clipboardData?.items || [])]
      .filter(item => item.type.startsWith("image/"))
      .map(item => item.getAsFile()).filter(Boolean)
    if (!files.length) return
    event.preventDefault()
    this.uploadFiles(files)
  }

  handleFileSelect(event) {
    this.uploadFiles([...event.target.files])
    event.target.value = ""
  }

  uploadFiles(files) {
    for (const file of files) {
      const row = this.templateTarget.content.firstElementChild.cloneNode(true)
      const upload = { file, row, localURL: URL.createObjectURL(file), state: "uploading" }
      row.querySelector(".image-upload-name").textContent = file.name
      const image = row.querySelector("img")
      image.src = upload.localURL
      image.onerror = () => { image.hidden = true }
      image.onload = () => { image.hidden = false }
      row.querySelector(".image-upload-preview").onclick = () => {
        const preview = this.dialogTarget.querySelector("img")
        preview.src = upload.url || upload.localURL
        preview.alt = file.name
        this.dialogTarget.showModal()
      }
      row.querySelector(".image-upload-remove").onclick = () => this.removeUpload(upload, true)
      row.querySelector(".image-upload-retry").onclick = () => this.queueUpload(upload)
      this.uploads.add(upload)
      this.listTarget.append(row)
      this.queueUpload(upload)
    }
  }

  queueUpload(upload) {
    this.setState(upload, "queued", "等待上传…")
    // ponytail: serialize uploads to limit phone memory; split the queue if transport becomes a bottleneck.
    this.uploadQueue = this.uploadQueue.then(() => this.uploads.has(upload) && this.uploadImage(upload))
  }

  async compressImage(file) {
    // Never flatten animated GIF/WebP/SVG or recompress already small images.
    if (file.size <= 512 * 1024 || !/^image\/(jpeg|png|heic|heif)$/.test(file.type)) return file
    const url = URL.createObjectURL(file)
    const canvas = document.createElement("canvas")
    try {
      if (file.type === "image/png") {
        // APNG declares acTL before IDAT; inspect headers without reading the whole file.
        let offset = 8
        while (offset + 8 <= file.size) {
          const header = new DataView(await file.slice(offset, offset + 8).arrayBuffer())
          if (header.getUint32(4) === 0x6163544c) return file
          if (header.getUint32(4) === 0x49444154) break
          offset += header.getUint32(0) + 12
        }
      }
      const image = new Image()
      image.src = url
      await image.decode() // Native decoding applies the photo's EXIF orientation.
      const scale = Math.min(1, 1920 / Math.max(image.naturalWidth, image.naturalHeight))
      canvas.width = Math.max(1, Math.round(image.naturalWidth * scale))
      canvas.height = Math.max(1, Math.round(image.naturalHeight * scale))
      canvas.getContext("2d").drawImage(image, 0, 0, canvas.width, canvas.height)
      const type = file.type === "image/png" ? "image/png" : "image/jpeg"
      const blob = await new Promise(resolve => canvas.toBlob(resolve, type, 0.82))
      if (!blob || blob.size >= file.size) return file
      const extension = blob.type === "image/png" ? ".png" : ".jpg"
      return new File([blob], file.name.replace(/\.[^.]+$/, "") + extension, { type: blob.type, lastModified: file.lastModified })
    } catch {
      // Browsers that cannot decode HEIC keep using the server converter.
      return file
    } finally {
      URL.revokeObjectURL(url)
      canvas.width = canvas.height = 0
    }
  }

  async uploadImage(upload) {
    this.setState(upload, "compressing", "正在压缩图片…")
    const progress = upload.row.querySelector("progress")
    progress.value = 0
    try {
      let file = upload.file
      if (!file.type) {
        const extension = file.name.split(".").pop().toLowerCase()
        const type = { jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png", heic: "image/heic", heif: "image/heif" }[extension]
        if (type) file = new File([file], file.name, { type, lastModified: file.lastModified })
      }
      if (!file.type.startsWith("image/")) throw new Error("只能上传图片文件")
      upload.preparedFile ||= await this.compressImage(file)
      if (!this.uploads.has(upload)) return
      if (upload.preparedFile.size > 10 * 1024 * 1024) throw new Error("图片处理后仍超过 10MB，请转换为 JPG 或缩小后重选")
      if (upload.preparedFile.size < upload.file.size) {
        URL.revokeObjectURL(upload.localURL)
        upload.localURL = URL.createObjectURL(upload.preparedFile)
        upload.row.querySelector("img").src = upload.localURL
      }
      this.setState(upload, "uploading", "正在上传… 0%")
      const data = await new Promise((resolve, reject) => {
        const xhr = upload.xhr = new XMLHttpRequest()
        xhr.open("POST", "/admin/posts/upload_image")
        xhr.responseType = "json"
        xhr.timeout = 120000
        xhr.setRequestHeader("X-CSRF-Token", document.querySelector('[name="csrf-token"]')?.content || "")
        xhr.upload.onprogress = event => {
          if (!this.uploads.has(upload) || !event.lengthComputable) return
          const percent = Math.min(100, Math.round(event.loaded * 100 / event.total))
          progress.value = percent
          this.setState(upload, percent === 100 ? "processing" : "uploading", percent === 100 ? "正在处理图片…" : `正在上传… ${percent}%`)
        }
        xhr.upload.onload = () => {
          if (!this.uploads.has(upload)) return
          progress.value = 100
          this.setState(upload, "processing", "正在处理图片…")
        }
        xhr.onload = () => {
          if (xhr.status >= 200 && xhr.status < 300 && xhr.response?.markdown && xhr.response?.url) resolve(xhr.response)
          else reject(new Error(xhr.response?.error || "上传失败，请重试"))
        }
        xhr.onerror = () => reject(new Error("网络异常，请重试"))
        xhr.ontimeout = () => reject(new Error("上传超时，请重试"))
        xhr.onabort = () => reject(new Error("上传已取消"))
        const body = new FormData()
        body.append("image", upload.preparedFile)
        xhr.send(body)
      })
      if (!this.uploads.has(upload)) return
      upload.markdown = data.markdown
      upload.url = data.url
      upload.row.querySelector("img").src = data.url
      const editor = this.editorTarget
      if (!this.hasSubmitTarget) {
        // Insert without replacing text selected during the upload.
        const position = editor.selectionStart ?? editor.value.length
        editor.setRangeText(`\n${data.markdown}\n`, position, position, "end")
      }
      this.setState(upload, "uploaded", "✓ 已上传")
      editor.dispatchEvent(new Event("input", { bubbles: true }))
    } catch (error) {
      if (this.uploads.has(upload)) this.setState(upload, "failed", error.message)
    }
  }

  setState(upload, state, message) {
    upload.state = state
    upload.row.dataset.state = state
    upload.row.querySelector(".image-upload-status span").textContent = message + (upload.preparedFile?.size < upload.file.size ? " · 已压缩" : "")
    upload.row.querySelector(".image-upload-retry").hidden = state !== "failed" || upload.preparedFile?.size > 10 * 1024 * 1024
    upload.row.querySelector("progress").hidden = !["uploading", "processing"].includes(state)
    this.updateForm()
  }

  removeUpload(upload, removeMarkdown = false) {
    this.uploads.delete(upload)
    upload.xhr?.abort()
    URL.revokeObjectURL(upload.localURL)
    upload.row.remove()
    if (removeMarkdown && upload.markdown && !this.hasSubmitTarget) {
      this.editorTarget.value = this.editorTarget.value.replace(upload.markdown, "")
      this.editorTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }
    this.updateForm()
  }

  updateForm() {
    const uploads = [...this.uploads]
    const compressing = uploads.some(upload => upload.state === "compressing")
    const pending = uploads.some(upload => !["uploaded", "failed"].includes(upload.state))
    const failed = uploads.some(upload => upload.state === "failed")
    this.uploadsTarget.hidden = !uploads.length
    this.countTarget.textContent = `· ${uploads.length} 张`
    this.hintTarget.textContent = failed ? "请重试或移除失败图片后发布，已输入的文字会保留。" : pending ? "图片处理完成后即可发布，可继续输入文字。" : "图片已就绪，点击缩略图可放大预览。"
    for (const { button, disabled } of this.submitButtons) button.disabled = disabled || pending || failed
    if (this.hasSubmitTarget) this.submitTarget.value = compressing ? "压缩中…" : pending ? "上传中…" : failed ? "待处理" : this.submitLabel
    this.editorTarget.setAttribute("aria-busy", String(pending))
  }

  closePreview() {
    this.dialogTarget.close()
  }

  clearUploads() {
    for (const upload of this.uploads) this.removeUpload(upload)
    if (this.hasDialogTarget && this.dialogTarget.open) this.dialogTarget.close()
  }
}
