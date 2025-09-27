import { Controller } from "@hotwired/stimulus"

/*
 * Clipboard Controller
 *
 * Usage:
 * <div data-controller="clipboard">
 *   <input data-clipboard-target="source" value="text to copy">
 *   <button data-action="click->clipboard#copy">Copy</button>
 * </div>
 */
export default class extends Controller<HTMLElement> {
  static targets = ["source"]

  // Declare targets
  declare readonly sourceTarget: HTMLInputElement

  // Copy content to clipboard
  copy(event: Event): void {
    event.preventDefault()

    const textToCopy = this.sourceTarget.value

    if (!textToCopy) {
      console.error('No text to copy found')
      this.showFailure()
      return
    }

    if (!window.copyToClipboard) {
      console.error('window.copyToClipboard not available')
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
    const button = this.getButton()
    const originalText = button.innerHTML
    const originalClass = button.className

    // Show success state
    button.innerHTML = 'Copied!'
    button.className = originalClass.replace(/btn-\w+/, 'btn-success')

    // Restore original state after 2 seconds
    setTimeout(() => {
      button.innerHTML = originalText
      button.className = originalClass
    }, 2000)
  }

  // Show failure feedback
  private showFailure(): void {
    const button = this.getButton()
    const originalText = button.innerHTML
    const originalClass = button.className

    // Show failure state
    button.innerHTML = 'Copy Failed!'
    button.className = originalClass.replace(/btn-\w+/, 'btn-danger')

    // Restore original state after 2 seconds
    setTimeout(() => {
      button.innerHTML = originalText
      button.className = originalClass
    }, 2000)
  }

  // Get the button to show feedback on
  private getButton(): HTMLElement {
    // Look for a button within the controller scope
    const button = this.element.querySelector('button')
    if (button) {
      return button
    }

    // Fall back to controller element if it's a button
    return this.element
  }

}
