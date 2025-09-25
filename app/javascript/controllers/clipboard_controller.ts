import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLButtonElement> {
  static targets: string[] = []
  static values = { text: String }

  // Declare values
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

    console.log('Attempting to copy:', textToCopy)
    window.copyToClipboard(textToCopy).then(() => {
      this.showSuccess()
    }).catch(_error => {
      this.showFailure()
    })
  }

  // Show success feedback
  private showSuccess(): void {
    const button = this.element
    const originalText = button.innerHTML
    const originalClass = button.className

    // Show success state
    button.innerHTML = 'Copied!'
    button.className = 'btn btn-success btn-sm'

    // Restore original state after 2 seconds
    setTimeout(() => {
      button.innerHTML = originalText
      button.className = originalClass
    }, 2000)
  }

  // Show failure feedback
  private showFailure(): void {
    const button = this.element
    const originalText = button.innerHTML
    const originalClass = button.className

    // Show failure state
    button.innerHTML = 'Copy Failed!'
    button.className = 'btn btn-danger btn-sm'

    // Restore original state after 2 seconds
    setTimeout(() => {
      button.innerHTML = originalText
      button.className = originalClass
    }, 2000)
  }

}
