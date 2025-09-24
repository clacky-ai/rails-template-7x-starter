// Stimulus Controller Validator
// Checks for missing stimulus controllers referenced in views

class StimulusValidator {
  private registeredControllers: Set<string> = new Set();
  private missingControllers: Set<string> = new Set();
  private hasReported: boolean = false;

  constructor() {
    this.initValidator();
  }

  private initValidator(): void {
    // Only run in development environment
    if (this.isDevelopment()) {
      this.collectRegisteredControllers();
      this.validateOnDOMReady();
    }
  }

  private isDevelopment(): boolean {
    // Check if we're in development mode
    return !!window.errorHandler
  }

  private collectRegisteredControllers(): void {
    // Get registered controllers from Stimulus application
    try {
      const stimulus = window.Stimulus as any;
      if (stimulus?.router?.modulesByIdentifier) {
        const modules = stimulus.router.modulesByIdentifier;
        for (const [identifier] of modules) {
          this.registeredControllers.add(identifier);
        }
      }
    } catch (error) {
      console.warn('Could not access Stimulus controllers:', error);
    }
  }

  private validateOnDOMReady(): void {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.validateControllers());
    } else {
      this.validateControllers();
    }

    // Also validate when new content is added dynamically
    this.observeNewContent();
  }

  private validateControllers(): void {
    const elements = document.querySelectorAll('[data-controller]');

    elements.forEach(element => {
      const controllers = element.getAttribute('data-controller')?.split(' ') || [];

      controllers.forEach(controller => {
        const trimmedController = controller.trim();
        if (trimmedController && !this.registeredControllers.has(trimmedController)) {
          this.missingControllers.add(trimmedController);
        }
      });
    });

    if (this.missingControllers.size > 0) {
      this.reportMissingControllers();
    }
  }

  private observeNewContent(): void {
    const observer = new MutationObserver(mutations => {
      let hasNewElements = false;

      mutations.forEach(mutation => {
        if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
          // Ignore error handler UI changes to prevent infinite loops
          const hasRelevantChanges = Array.from(mutation.addedNodes).some(node => {
            if (node.nodeType === Node.ELEMENT_NODE) {
              const element = node as Element;
              // Skip error handler elements
              if (element.id === 'js-error-status-bar' ||
                  element.closest('#js-error-status-bar')) {
                return false;
              }
              // Only care about elements with data-controller attributes
              return element.hasAttribute('data-controller') ||
                     element.querySelector('[data-controller]');
            }
            return false;
          });

          if (hasRelevantChanges) {
            hasNewElements = true;
          }
        }
      });

      if (hasNewElements) {
        setTimeout(() => this.validateControllers(), 100);
      }
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true
    });
  }

  private reportMissingControllers(): void {
    // Prevent duplicate reports
    if (this.hasReported) {
      return;
    }

    const missingList = Array.from(this.missingControllers);
    this.hasReported = true;

    // Report to error handler if available
    if (window.errorHandler) {
      window.errorHandler.handleError({
        message: `Missing Stimulus controllers: ${missingList.join(', ')}`,
        type: 'stimulus',
        timestamp: new Date().toISOString(),
        missingControllers: missingList,
        suggestion: `Run: rails generate stimulus_controller ${missingList[0]}`
      });
    } else {
      // Fallback to console
      console.error('🔴 Missing Stimulus Controllers:', missingList);
      console.info('💡 Generate missing controllers:', missingList.map(name =>
        `rails generate stimulus_controller ${name}`
      ).join('\n'));
    }
  }

  // Public API
  public getRegisteredControllers(): string[] {
    return Array.from(this.registeredControllers);
  }

  public getMissingControllers(): string[] {
    return Array.from(this.missingControllers);
  }

  public forceValidation(): void {
    this.missingControllers.clear();
    this.hasReported = false;
    this.validateControllers();
  }
}

// Note: Global types are declared in types/global.d.ts

// Initialize validator
if (typeof window !== 'undefined') {
  window.stimulusValidator = new StimulusValidator();
}

export default StimulusValidator;
