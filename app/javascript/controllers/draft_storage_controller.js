import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor", "autoSaveStatus", "lastSaveTime"]
  static values = {
    postId: String,
    postUpdatedAt: Number
  }

  connect() {
    this.loadFromLocalStorage()
    this.startAutoSave()
  }

  disconnect() {
    if (this.autoSaveInterval) {
      clearInterval(this.autoSaveInterval)
    }
  }

  handleKeydown(event) {
    // 检测 Ctrl+S 或 Cmd+S
    if ((event.ctrlKey || event.metaKey) && event.key === 's') {
      event.preventDefault()
      this.saveToLocalStorage()
    }
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

  handleSubmit() {
    // 清除本地存储
    const key = this.getStorageKey()
    localStorage.removeItem(key)
  }
}