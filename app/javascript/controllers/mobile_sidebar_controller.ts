import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static targets = ["sidebar"]

  declare readonly sidebarTarget: HTMLElement

  connect(): void {
    // 确保初始状态正确
    this.hide()
  }

  toggle(): void {
    const isHidden = this.sidebarTarget.style.display === 'none'
    if (isHidden) {
      this.show()
    } else {
      this.hide()
    }
  }

  hide(): void {
    if (this.sidebarTarget) {
      this.sidebarTarget.style.display = 'none'
    }
  }

  show(): void {
    if (this.sidebarTarget) {
      this.sidebarTarget.style.display = 'flex'
    }
  }
}
