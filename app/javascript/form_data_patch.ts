/**
 * FormData Patch - Include disabled fields
 *
 * Browser default: disabled fields are NOT submitted
 * This patch: disabled fields ARE submitted
 *
 * Why: AI may disable inputs before form submission, breaking form data collection.
 * This patch ensures disabled fields are still included in FormData.
 */

(function() {
  const OriginalFormData = window.FormData;

  window.FormData = class PatchedFormData extends OriginalFormData {
    constructor(form?: HTMLFormElement) {
      super(form);

      if (form) {
        // Collect disabled fields that would normally be excluded
        const disabledFields = form.querySelectorAll<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>(
          'input[disabled][name], textarea[disabled][name], select[disabled][name]'
        );

        disabledFields.forEach(field => {
          // Only add if field has a name and wasn't already added
          if (field.name && !this.has(field.name)) {
            if (field instanceof HTMLInputElement) {
              // Handle checkboxes and radios
              if ((field.type === 'checkbox' || field.type === 'radio') && !field.checked) {
                return; // Skip unchecked checkboxes/radios
              }

              // Handle file inputs
              if (field.type === 'file' && field.files) {
                Array.from(field.files).forEach(file => {
                  this.append(field.name, file);
                });
                return;
              }
            }

            // Add regular field value
            this.append(field.name, field.value);
          }
        });
      }
    }
  } as any;

  // Preserve static methods
  Object.setPrototypeOf(window.FormData, OriginalFormData);
  Object.setPrototypeOf(window.FormData.prototype, OriginalFormData.prototype);
})();
