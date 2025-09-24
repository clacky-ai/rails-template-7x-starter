import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static targets = ["button"]
  static values = { text: String }

  // Declare targets and values
  declare readonly buttonTarget: HTMLButtonElement
  declare readonly hasButtonTarget: boolean
  declare readonly textValue: string

  // Copy content to clipboard
  copy(event: Event): void {
    event.preventDefault()

    // Decode escaped text from Rails (reverse of `j` helper)
    let textToCopy = this.textValue
    if (textToCopy) {
      textToCopy = textToCopy
        .replace(/\\n/g, '\n')        // Convert \\n back to \n
        .replace(/\\r/g, '\r')        // Convert \\r back to \r
        .replace(/\\t/g, '\t')        // Convert \\t back to \t
        .replace(/\\"/g, '"')         // Convert \\" back to "
        .replace(/\\'/g, "'")         // Convert \\' back to '
        .replace(/\\\\/g, '\\')       // Convert \\\\ back to \\ (must be last)
    }

    if (!textToCopy) {
      console.error('no textToCopy')
      this.showFailure()
      return
    }

    if (!window.copyToClipboard) {
      console.error('no window.copyToClipboard')
      this.showFailure()
      return
    }

    window.copyToClipboard(textToCopy).then(() => {
      this.showSuccess()
    }).catch(_error => {
      this.showFailure()
    })
  }

  // Show success feedback
  private showSuccess(): void {
    if (!this.hasButtonTarget) return

    const button = this.buttonTarget
    const originalText = button.innerHTML
    const originalClass = button.className

    // Show success state
    button.innerHTML = 'Copied!'
    button.className = 'border border-green-600 text-green-600 hover:bg-green-50 font-medium py-1 px-3 rounded text-sm transition-colors'

    // Restore original state after 2 seconds
    setTimeout(() => {
      button.innerHTML = originalText
      button.className = originalClass
    }, 2000)
  }

  // Show failure feedback
  private showFailure(): void {
    if (!this.hasButtonTarget) return

    const button = this.buttonTarget
    const originalText = button.innerHTML
    const originalClass = button.className

    // Show failure state
    button.innerHTML = 'Copy Failed!'
    button.className = 'border border-red-600 text-red-600 hover:bg-red-50 font-medium py-1 px-3 rounded text-sm transition-colors'

    // Restore original state after 2 seconds
    setTimeout(() => {
      button.innerHTML = originalText
      button.className = originalClass
    }, 2000)
  }

  // Fallback copy method
  private fallbackCopy(text: string): void {
    const textArea = document.createElement('textarea')
    textArea.value = text
    textArea.style.position = 'fixed'
    textArea.style.opacity = '0'
    document.body.appendChild(textArea)
    textArea.select()

    try {
      const success = document.execCommand('copy')
      document.body.removeChild(textArea)
      if (success) {
        this.showSuccess()
      } else {
        this.showFailure()
      }
    } catch (_error) {
      document.body.removeChild(textArea)
      this.showFailure()
    }
  }
}
