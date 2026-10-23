// Enabled synchronously in the head; without JavaScript images stay fully visible.
document.documentElement.classList.add("progressive-images-enabled")
function revealImages() {
  document.querySelectorAll("img[data-lqip]").forEach((image) => {
    if (image.dataset.revealStarted) return
    image.dataset.revealStarted = "true"
    const reveal = async () => {
      try { await image.decode() } catch (_) { /* Let broken image alt text remain visible. */ }
      image.classList.add("image-decoded")
    }
    if (image.complete) reveal()
    else {
      image.addEventListener("load", reveal, { once: true })
      image.addEventListener("error", reveal, { once: true })
    }
  })
}
document.addEventListener("DOMContentLoaded", revealImages)
document.addEventListener("turbo:load", revealImages)
