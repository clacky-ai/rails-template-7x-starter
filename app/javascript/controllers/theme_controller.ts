import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static targets = ["lightIcon", "darkIcon"]
  static values = { storageKey: String }

  declare readonly lightIconTarget: HTMLElement
  declare readonly darkIconTarget: HTMLElement
  declare readonly storageKeyValue: string

  connect(): void {
    this.initializeTheme()
  }

  toggle(): void {
    const isDark = document.documentElement.classList.contains('dark')
    const newIsDark = !isDark
    
    localStorage.setItem(this.storageKeyValue, JSON.stringify(newIsDark))
    this.updateTheme(newIsDark)
  }

  private initializeTheme(): void {
    const savedIsDark = this.getSavedTheme()
    this.updateTheme(savedIsDark)
  }

  private getSavedTheme(): boolean {
    return JSON.parse(localStorage.getItem(this.storageKeyValue) || 'false')
  }

  private updateTheme(isDark: boolean): void {
    if (isDark) {
      document.documentElement.classList.add('dark')
      this.lightIconTarget.classList.add('hidden')
      this.darkIconTarget.classList.remove('hidden')
    } else {
      document.documentElement.classList.remove('dark')
      this.lightIconTarget.classList.remove('hidden')
      this.darkIconTarget.classList.add('hidden')
    }
  }
}
