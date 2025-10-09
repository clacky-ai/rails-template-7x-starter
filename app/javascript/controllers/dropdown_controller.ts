import { Controller } from '@hotwired/stimulus'

/**
 * Dropdown Controller
 *
 * A versatile controller for toggling visibility of dropdown menus, sidebars, and modals.
 *
 * Usage:
 *   <div data-controller="dropdown">
 *     <button data-action="click->dropdown#toggle">Toggle</button>
 *     <div data-dropdown-target="menu" class="hidden">
 *       Menu content...
 *     </div>
 *   </div>
 *
 * Targets:
 *   - menu (required): The element to show/hide
 *   - trigger (optional): The button that triggers the dropdown (gets aria-expanded attribute)
 *
 * Values:
 *   - closeOnClickOutside (boolean, default: true): Auto-close when clicking outside
 *
 * Actions:
 *   - toggle: Toggle menu visibility
 *   - open: Show menu
 *   - close: Hide menu
 *
 * Examples:
 *   // User dropdown with auto-close
 *   <div data-controller="dropdown">
 *     <button data-dropdown-target="trigger" data-action="click->dropdown#toggle">Menu</button>
 *     <div data-dropdown-target="menu" class="hidden">...</div>
 *   </div>
 *
 *   // Mobile sidebar without auto-close
 *   <div data-controller="dropdown" data-dropdown-close-on-click-outside-value="false">
 *     <button data-action="click->dropdown#toggle">☰</button>
 *     <div data-dropdown-target="menu" class="hidden">...</div>
 *   </div>
 */
export default class extends Controller<HTMLElement> {
  static targets = ['menu', 'trigger']
  static values = {
    closeOnClickOutside: { type: Boolean, default: true }
  }

  declare readonly menuTarget: HTMLElement
  declare readonly triggerTarget: HTMLElement
  declare readonly hasTriggerTarget: boolean
  declare readonly closeOnClickOutsideValue: boolean

  connect(): void {
    if (this.closeOnClickOutsideValue) {
      document.addEventListener('click', this.clickOutside.bind(this))
    }
  }

  disconnect(): void {
    if (this.closeOnClickOutsideValue) {
      document.removeEventListener('click', this.clickOutside.bind(this))
    }
  }

  toggle(event: Event): void {
    event.stopPropagation()
    const isHidden = this.menuTarget.classList.contains('hidden')
    if (isHidden) {
      this.open(event)
    } else {
      this.close(event)
    }
  }

  open(event: Event): void {
    event.stopPropagation()
    this.menuTarget.classList.remove('hidden')
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute('aria-expanded', 'true')
    }
  }

  close(event: Event): void {
    event.stopPropagation()
    this.menuTarget.classList.add('hidden')
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute('aria-expanded', 'false')
    }
  }

  private clickOutside(event: Event): void {
    if (!this.element.contains(event.target as Node)) {
      this.close(event)
    }
  }
}
