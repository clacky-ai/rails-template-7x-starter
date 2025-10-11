import { Controller } from "@hotwired/stimulus"

interface BeforeInstallPromptEvent extends Event {
  readonly platforms: string[]
  readonly userChoice: Promise<{
    outcome: 'accepted' | 'dismissed'
    platform: string
  }>
  prompt(): Promise<void>
}

/**
 * PWA Install Controller
 *
 * Handles Progressive Web App installation prompt
 *
 * Usage:
 *   <div data-controller="pwa-install">
 *     <button
 *       data-pwa-install-target="installButton"
 *       data-action="click->pwa-install#install"
 *       class="hidden">
 *       Install App
 *     </button>
 *   </div>
 */
export default class extends Controller {
  declare readonly installButtonTarget: HTMLButtonElement
  declare readonly hasInstallButtonTarget: boolean

  private deferredPrompt: BeforeInstallPromptEvent | null = null

  connect() {
    window.addEventListener('beforeinstallprompt', this.handleBeforeInstallPrompt.bind(this))
    window.addEventListener('appinstalled', this.handleAppInstalled.bind(this))

    if (this.isStandalone()) {
      this.hideInstallButton()
    }
  }

  disconnect() {
    window.removeEventListener('beforeinstallprompt', this.handleBeforeInstallPrompt.bind(this))
    window.removeEventListener('appinstalled', this.handleAppInstalled.bind(this))
  }

  private handleBeforeInstallPrompt(e: Event) {
    e.preventDefault()
    this.deferredPrompt = e as BeforeInstallPromptEvent

    if (this.hasInstallButtonTarget) {
      this.installButtonTarget.classList.remove('hidden')
    }
  }

  private handleAppInstalled() {
    this.deferredPrompt = null
    this.hideInstallButton()
  }

  async install() {
    if (!this.deferredPrompt) {
      return
    }

    this.deferredPrompt.prompt()

    const { outcome } = await this.deferredPrompt.userChoice

    if (outcome === 'accepted') {
      console.log('PWA installation accepted')
    }

    this.deferredPrompt = null
    this.hideInstallButton()
  }

  private isStandalone(): boolean {
    return window.matchMedia('(display-mode: standalone)').matches ||
           (window.navigator as any).standalone === true
  }

  private hideInstallButton() {
    if (this.hasInstallButtonTarget) {
      this.installButtonTarget.classList.add('hidden')
    }
  }

  static targets = ["installButton"]
}
