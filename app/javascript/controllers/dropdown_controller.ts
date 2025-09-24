import { Controller } from '@hotwired/stimulus'

export default class extends Controller<HTMLElement> {
  static targets = ['menu'] as const

  declare readonly menuTarget: HTMLElement

  connect(): void {
    // Click outside to close
    document.addEventListener('click', this.clickOutside.bind(this))
  }

  disconnect(): void {
    document.removeEventListener('click', this.clickOutside.bind(this))
  }

  toggle(event: Event): void {
    event.stopPropagation()
    this.menuTarget.classList.toggle('hidden')
  }

  close(): void {
    this.menuTarget.classList.add('hidden')
  }

  private clickOutside(event: Event): void {
    if (!this.element.contains(event.target as Node)) {
      this.close()
    }
  }
}
