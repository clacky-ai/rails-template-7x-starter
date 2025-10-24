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

  // data-disable-with → data-turbo-submits-with (skip if turbo is disabled)
  document.querySelectorAll<HTMLElement>('[data-disable-with]:not([data-turbo-submits-with])').forEach(el => {
    // Skip if element or its parent form has data-turbo="false"
    if (el.dataset.turbo === 'false') return
    const parentForm = el.closest('form')
    if (parentForm?.dataset.turbo === 'false') return

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

// Handle data-disable-with for forms with data-turbo="false" (like OAuth)
// Since Turbo is disabled, we need to manually handle submit element disable/enable
function handleNonTurboFormSubmit(event: Event): void {
  const form = event.target as HTMLFormElement
  const submit = form.querySelector<HTMLButtonElement | HTMLInputElement>(
    'button[type="submit"], button:not([type]), input[type="submit"]'
  )

  // Check if turbo is disabled
  const isTurboDisabled = form.dataset.turbo === 'false' || submit?.dataset.turbo === 'false'

  if (isTurboDisabled && submit?.dataset.disableWith) {
    const isButton = submit instanceof HTMLButtonElement
    const key = isButton ? 'textContent' : 'value'
    submit.dataset.originalText = submit[key] || ''
    submit[key] = submit.dataset.disableWith
    submit.disabled = true
  }
}

// Re-enable submit elements when page becomes visible (e.g., switching back from payment window)
function handleVisibilityChange(): void {
  if (document.visibilityState === 'visible') {
    const selector = 'form[data-turbo="false"] [disabled][data-original-text], [data-turbo="false"][disabled][data-original-text]'
    document.querySelectorAll<HTMLButtonElement | HTMLInputElement>(selector).forEach(submit => {
      submit.disabled = false
      const originalText = submit.dataset.originalText
      if (originalText) {
        const key = submit instanceof HTMLButtonElement ? 'textContent' : 'value'
        submit[key] = originalText
        delete submit.dataset.originalText
      }
    })
  }
}

document.addEventListener('submit', handleNonTurboFormSubmit)
document.addEventListener('visibilitychange', handleVisibilityChange)

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

// Register custom Turbo Stream action for redirect with turbo: false
StreamActions.redirect = function(this: any) {
  const url = this.getAttribute('url')
  const turbo = this.getAttribute('data-turbo')

  if (url) {
    if (turbo === 'false') {
      // Full page redirect (turbo: false)
      // Check if in iframe and open in new window to avoid X-Frame-Options errors
      if (window.self !== window.parent) {
        // In iframe, open in new window
        window.open(url, '_blank')
      } else {
        // Normal redirect
        window.location.href = url
      }
    } else {
      // Turbo navigation
      Turbo.visit(url)
    }
  }
}
