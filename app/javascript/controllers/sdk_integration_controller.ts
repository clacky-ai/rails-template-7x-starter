import { Controller } from "@hotwired/stimulus"

// SDK Integration Controller
// Handles SDK availability detection and communication with external development tools
export default class extends Controller<HTMLElement> {
  static targets = [
    "sdkButton"
  ]

  static values = {
    message: String,
    action: String
  }

  // Declare targets and values
  declare readonly sdkButtonTarget: HTMLButtonElement
  declare readonly hasSdkButtonTarget: boolean
  declare readonly messageValue: string
  declare readonly actionValue: string

  connect(): void {
    // Check SDK availability and show SDK buttons if available
    this.checkSDKAvailability()
  }

  // Send message to chatbox (SDK integration)
  sendToChatbox(): void {
    if (!window.sdkUtils || !window.sdkUtils.sendMessage) {
      console.warn('SDK not available')
      return
    }

    const message = this.messageValue || this.generateDefaultMessage()
    window.sdkUtils.sendMessage(message)
  }

  // Send error to chatbox for fixing
  sendErrorToChatbox(): void {
    if (!window.sdkUtils || !window.sdkUtils.sendErrorForFix) {
      console.warn('SDK not available')
      return
    }

    const action = this.actionValue || 'sendErrorForFix'
    if (action === 'sendErrorForFix') {
      const errorMessage = this.messageValue || 'Unknown error'
      window.sdkUtils.sendErrorForFix({ errorMessage })
    } else {
      const message = this.messageValue || this.generateDefaultMessage()
      window.sdkUtils.sendMessage(message)
    }
  }

  // Check SDK availability and show/hide SDK buttons
  private checkSDKAvailability(): void {
    if (!this.hasSdkButtonTarget) return

    const checkAndShow = () => {
      if (window.isSDKAvailable && window.isSDKAvailable()) {
        this.sdkButtonTarget.style.display = 'block'
        return true
      }
      return false
    }

    // Initial check
    if (!checkAndShow()) {
      // Retry after 1 second (in case SDK is loading)
      setTimeout(checkAndShow, 1000)
      // Final retry after 3 seconds
      setTimeout(checkAndShow, 3000)
    }
  }

  // Generate default message for SDK
  private generateDefaultMessage(): string {
    const url = window.location.pathname.substring(1)
    return `Please help me with this page: ${url}

URL: ${window.location.href}
Path: ${url}

I need assistance with this page.`
  }
}
