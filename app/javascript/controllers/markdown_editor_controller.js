import { Controller } from "@hotwired/stimulus"
import { marked } from "marked"

// 设置 marked 选项，启用 GFM（GitHub Flavored Markdown）
marked.setOptions({
  gfm: true,
  breaks: true,
  sanitize: false
})

export default class extends Controller {
  static targets = ["editor", "preview", "autoSaveStatus", "editorTab", "previewTab", "lastSaveTime"]
  static values = {
    postId: String,
    postUpdatedAt: Number
  }

  connect() {
    this.loadFromLocalStorage()
    this.startAutoSave()
    this.updatePreview()
    this.switchToEditor()
  }

  disconnect() {
    if (this.autoSaveInterval) {
      clearInterval(this.autoSaveInterval)
    }
  }

  handleKeydown(event) {
    // 检测 Ctrl+S 或 Cmd+S
    if ((event.ctrlKey || event.metaKey) && event.key === 's') {
      event.preventDefault() // 阻止浏览器默认的保存行为
      this.saveToLocalStorage()
    }
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

  startAutoSave() {
    // 立即进行一次保存
    this.saveToLocalStorage()

    this.autoSaveInterval = setInterval(() => {
      this.saveToLocalStorage()
    }, 60000) // 每分钟保存一次
  }

  getStorageKey() {
    return `post_draft_${this.postIdValue}`
  }

  saveToLocalStorage() {
    const content = this.editorTarget.value
    const now = new Date()
    const key = this.getStorageKey()

    // 保存内容和时间戳
    localStorage.setItem(key, JSON.stringify({
      content: content,
      timestamp: now.getTime(),
      timeString: now.toLocaleTimeString('zh-CN', {
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
      })
    }))

    this.updateAutoSaveStatus("已自动保存")
    this.lastSaveTimeTarget.textContent = `上次保存时间：${now.toLocaleTimeString('zh-CN', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    })}`

    // 3秒后清除状态信息，但保留保存时间
    setTimeout(() => {
      this.updateAutoSaveStatus("")
    }, 3000)
  }

  loadFromLocalStorage() {
    const key = this.getStorageKey()
    const savedData = localStorage.getItem(key)

    if (savedData) {
      try {
        const { content, timestamp, timeString } = JSON.parse(savedData)
        const postUpdatedAt = this.postUpdatedAtValue * 1000 // 转换为毫秒

        // 如果是新建文章，或者本地存储的时间晚于文章更新时间，使用本地存储的内容
        if (this.postIdValue === 'new' || timestamp > postUpdatedAt) {
          this.editorTarget.value = content
          this.updateAutoSaveStatus(this.postIdValue === 'new' ? "已加载草稿" : "已加载本地较新的草稿")
          this.lastSaveTimeTarget.textContent = `上次保存时间：${timeString}`
        } else {
          // 如果本地存储的内容较旧，清除它
          localStorage.removeItem(key)
        }
      } catch (e) {
        console.error("解析本地存储数据失败:", e)
        localStorage.removeItem(key)
      }
    }
  }

  updateAutoSaveStatus(message) {
    this.autoSaveStatusTarget.textContent = message
  }
}