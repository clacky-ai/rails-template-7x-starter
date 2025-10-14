// base dependency library, it should be only imported by `admin.ts` and `application.ts`.
//
// Global patches (must be first)
import './form_data_patch'

import * as ActiveStorage from '@rails/activestorage'
import Alpine from 'alpinejs'
import * as ActionCable from "@rails/actioncable"
import { createConsumer } from "@rails/actioncable"
// @ts-ignore - @hotwired/turbo-rails has no type definitions, uses @hotwired/turbo types
import { Turbo } from "@hotwired/turbo-rails"
import { StreamActions } from "@hotwired/turbo"
import './controllers'
import './clipboard_utils'
import './sdk_utils'
import './stimulus_validator'
import './channels'

ActiveStorage.start()
window.ActionCable = ActionCable

Alpine.start()
window.Alpine = Alpine

window.App = window.App || { cable: null }
window.App.cable = createConsumer()

// Turbo configuration: Enable Drive for full SPA experience
// Turbo Drive is now enabled by default (replaced Rails-UJS)
window.Turbo = Turbo

// Global function to restore disabled buttons (for ActionCable callbacks)
window.restoreButtonStates = function(): void {
  const disabledButtons = document.querySelectorAll<HTMLInputElement | HTMLButtonElement>(
    'input[type="submit"][disabled], button[type="submit"][disabled], button:not([type])[disabled]'
  )

  disabledButtons.forEach((button: HTMLInputElement | HTMLButtonElement) => {
    button.disabled = false
    // Restore original text if data-disable-with was used
    const originalText = button.dataset.originalText
    if (originalText) {
      button.textContent = originalText
      delete button.dataset.originalText
    }
    // Remove loading class if present
    button.classList.remove('loading')
  })
}

// Legacy Rails-UJS compatibility: auto-convert attributes to Turbo equivalents
function convertLegacyAttributes(): void {
  // data-method → data-turbo-method
  document.querySelectorAll<HTMLElement>('[data-method]:not([data-turbo-method])').forEach(el => {
    const method = el.getAttribute('data-method')
    if (method && method !== 'get') {
      el.setAttribute('data-turbo-method', method)
      el.removeAttribute('data-method')
    }
  })

  // data-confirm → data-turbo-confirm
  document.querySelectorAll<HTMLElement>('[data-confirm]:not([data-turbo-confirm])').forEach(el => {
    const confirm = el.getAttribute('data-confirm')
    if (confirm) {
      el.setAttribute('data-turbo-confirm', confirm)
      el.removeAttribute('data-confirm')
    }
  })

  // Remove data-remote="true" (Turbo handles by default)
  document.querySelectorAll<HTMLElement>('[data-remote="true"]').forEach(el => {
    el.removeAttribute('data-remote')
  })

  // data-disable-with → data-turbo-submits-with
  document.querySelectorAll<HTMLElement>('[data-disable-with]:not([data-turbo-submits-with])').forEach(el => {
    const text = el.getAttribute('data-disable-with')
    if (text) {
      el.setAttribute('data-turbo-submits-with', text)
      el.removeAttribute('data-disable-with')
    }
  })
}

document.addEventListener('DOMContentLoaded', convertLegacyAttributes)
document.addEventListener('turbo:load', convertLegacyAttributes)
document.addEventListener('turbo:frame-load', convertLegacyAttributes)

// Register custom Turbo Stream action for async job errors
StreamActions.report_async_error = function(this: any) {
  const errorData = JSON.parse(this.getAttribute('data-error') || '{}')

  if (window.errorHandler) {
    window.errorHandler.handleError({
      type: 'asyncjob',
      message: errorData.message || 'Async job error occurred',
      timestamp: new Date().toISOString(),
      job_class: errorData.job_class,
      job_id: errorData.job_id,
      queue: errorData.queue,
      exception_class: errorData.exception_class,
      backtrace: errorData.backtrace,
      details: errorData
    })
  }
}
