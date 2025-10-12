// base dependency library, it should be only imported by `admin.ts` and `application.ts`.
//
import RailsUjs from '@rails/ujs'
import * as ActiveStorage from '@rails/activestorage'
import Alpine from 'alpinejs'
import * as ActionCable from "@rails/actioncable"
import { createConsumer } from "@rails/actioncable"
import * as Turbo from "@hotwired/turbo"
import './controllers'
import './clipboard_utils'
import './sdk_utils'
import './stimulus_validator'
import './channels'

RailsUjs.start()

ActiveStorage.start()
window.ActionCable = ActionCable

Alpine.start()
window.Alpine = Alpine

window.App = window.App || { cable: null }
window.App.cable = createConsumer()

// Turbo configuration: ONLY enable Turbo Streams, disable Drive and Frames
Turbo.session.drive = false  // Disable automatic page navigation interception
window.Turbo = Turbo

// Global function to restore disabled buttons (for ActionCable callbacks)
window.restoreButtonStates = function(): void {
  const disabledButtons = document.querySelectorAll<HTMLInputElement | HTMLButtonElement>(
    'input[type="submit"][disabled], button[type="submit"][disabled], button:not([type])[disabled]'
  );

  disabledButtons.forEach((button: HTMLInputElement | HTMLButtonElement) => {
    button.disabled = false;
    // Restore original text if data-disable-with was used
    const originalText = button.dataset.originalText;
    if (originalText) {
      button.textContent = originalText;
      delete button.dataset.originalText;
    }
    // Remove loading class if present
    button.classList.remove('loading');
  });
}

document.addEventListener('DOMContentLoaded', (): void => {
  const disableRemoteForms = document.querySelectorAll<HTMLFormElement>('form[data-remote="true"]');

  disableRemoteForms.forEach((form: HTMLFormElement) => {
    form.removeAttribute('data-remote');
  });

  const turboElements = document.querySelectorAll<HTMLElement>('[data-turbo-method], [data-turbo-confirm]');
  turboElements.forEach((element: HTMLElement) => {
    if (element.hasAttribute('data-turbo-method')) {
      const method = element.getAttribute('data-turbo-method');
      if (method) element.setAttribute('data-method', method);
    }
    if (element.hasAttribute('data-turbo-confirm')) {
      const confirm = element.getAttribute('data-turbo-confirm');
      if (confirm) element.setAttribute('data-confirm', confirm);
    }
  });
});
