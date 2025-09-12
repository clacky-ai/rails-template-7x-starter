// base dependency library, it should be only imported by `admin.js` and `application.js`.
//
import RailsUjs from '@rails/ujs'
import * as ActiveStorage from '@rails/activestorage'
import Alpine from 'alpinejs'
import * as ActionCable from "@rails/actioncable"
import './channels'

RailsUjs.start()

ActiveStorage.start()
window.ActionCable = ActionCable

Alpine.start()
window.Alpine = Alpine

document.addEventListener('DOMContentLoaded', () => {
  const disableRemoteForms = document.querySelectorAll('form[data-remote="true"]');

  disableRemoteForms.forEach(form => {
    form.removeAttribute('data-remote');
  });
});

// Optional: Custom JavaScript for Tailwind-based UI
document.addEventListener('DOMContentLoaded', () => {
  // Initialize any custom components here

  // Mobile menu toggle
  const mobileMenuButton = document.querySelector('[data-mobile-menu]');
  const mobileMenu = document.querySelector('[data-mobile-menu-target]');

  if (mobileMenuButton && mobileMenu) {
    mobileMenuButton.addEventListener('click', () => {
      mobileMenu.classList.toggle('hidden');
    });
  }

  // Dropdown functionality (if not using Alpine.js)
  const dropdownButtons = document.querySelectorAll('[data-dropdown]');

  dropdownButtons.forEach(button => {
    button.addEventListener('click', (e) => {
      e.stopPropagation();
      const target = document.querySelector(`[data-dropdown-target="${button.dataset.dropdown}"]`);
      if (target) {
        target.classList.toggle('hidden');
      }
    });
  });
});

