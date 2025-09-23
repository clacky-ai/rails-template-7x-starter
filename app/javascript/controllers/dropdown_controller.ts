import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static targets = ["menu"]

  declare readonly menuTarget: HTMLElement
  private clickOutsideHandler = this.handleClickOutside.bind(this)

  connect(): void {
    document.addEventListener('click', this.clickOutsideHandler)
    // 监听 ESC 键
    document.addEventListener('keydown', this.handleKeydown.bind(this))
  }

  disconnect(): void {
    document.removeEventListener('click', this.clickOutsideHandler)
    document.removeEventListener('keydown', this.handleKeydown.bind(this))
  }

  toggle(): void {
    this.menuTarget.classList.toggle('hidden')
  }

  hide(): void {
    this.menuTarget.classList.add('hidden')
  }

  show(): void {
    this.menuTarget.classList.remove('hidden')
  }

  private handleClickOutside(event: Event): void {
    const target = event.target as Element
    if (!this.element.contains(target)) {
      this.hide()
    }
  }

  private handleKeydown(event: KeyboardEvent): void {
    if (event.key === 'Escape') {
      this.hide()
    }
  }
}
