// Stimulus Controller Validator
// Checks for missing stimulus controllers referenced in views

class StimulusValidator {
  private registeredControllers: Set<string> = new Set();
  private missingControllers: Set<string> = new Set();
  private hasReported: boolean = false;
  private elementIssues: Map<string, string[]> = new Map();
  private stimulus = window.Stimulus;

  constructor() {
    this.initValidator();
  }

  private initValidator(): void {
    // Only run in development environment
    //
    if (!this.isDevelopment()) {
      console.log('StimulusValidator not enable in non-develop environment.')
      return
    }

    if (!window.Stimulus) {
      console.log('StimulusValidator not enable while Stimulus not found')
      return
    }

    this.setupStimulusErrorHandler();
    this.collectRegisteredControllers();
    this.validateOnDOMReady();
    this.interceptActionClicks();
  }

  private isDevelopment(): boolean {
    return !!window.errorHandler
  }

  private setupStimulusErrorHandler(): void {
    // Setup Stimulus application error handling using application.handleError
    const setupHandler = () => {
      const stimulus = window.Stimulus as any;
      if (stimulus && typeof stimulus.handleError === 'undefined') {
        stimulus.handleError = (error: Error, message: string, detail: any) => {
          console.error('Stimulus Error:', { error, message, detail });

          // Use the global error handler to capture Stimulus errors
          if (window.errorHandler) {
            let errorMessage = message || error.message || 'Stimulus error occurred';
            let controllerName = '';
            let action = '';
            let subType: 'missing-controller' | 'scope-error' | 'positioning-issues' | 'action-click' | 'missing-target' | 'missing-action' | 'method-not-found' = 'scope-error';
            let suggestion = '';
            let elementInfo = null;

            // Extract controller and action information from detail or error context
            if (detail) {
              if (detail.identifier) {
                controllerName = detail.identifier;
              }
              if (detail.action) {
                action = detail.action;
              }
              if (detail.element) {
                elementInfo = {
                  tagName: detail.element.tagName,
                  id: detail.element.id,
                  className: detail.element.className,
                  outerHTML: `${detail.element.outerHTML?.substring(0, 200)  }...`
                };
              }
            }

            // Analyze error type and provide specific suggestions
            if (error.message.includes('Controller') && error.message.includes('is not defined')) {
              subType = 'missing-controller';
              const controllerMatch = error.message.match(/(\w+)Controller is not defined/);
              if (controllerMatch) {
                controllerName = controllerMatch[1].toLowerCase();
                errorMessage = `Stimulus controller "${controllerName}" is not defined or not registered`;
                suggestion = `Make sure to import and register the "${controllerName}" controller in app/javascript/controllers/index.ts. ` +
                  `Check if the controller file exists at app/javascript/controllers/${controllerName}_controller.ts`;
              }
            } else if (error.message.includes('Missing target element')) {
              subType = 'missing-target';
              suggestion = 'Check that the target element exists in the DOM and has the correct data-[controller]-target attribute';
            } else if (error.message.includes('Missing action')) {
              subType = 'missing-action';
              suggestion = 'Verify that the action method exists in the controller class and is properly defined';
            } else if (message && message.includes('click')) {
              subType = 'action-click';
              suggestion = 'Check if the click action handler exists and the element has the correct data-action attribute';
            }

            // Report the error to the error handler
            window.errorHandler.handleError({
              message: errorMessage,
              type: 'stimulus',
              subType: subType,
              controllerName: controllerName,
              action: action,
              suggestion: suggestion,
              elementInfo: elementInfo,
              details: {
                originalMessage: message,
                error: {
                  name: error.name,
                  message: error.message,
                  stack: error.stack
                },
                detail: detail
              },
              timestamp: new Date().toISOString(),
              filename: 'stimulus-application',
              error: error
            });
          }
        };

        console.log('Stimulus error handling configured via stimulus_validator');
      }
    };

    // Try to setup immediately if Stimulus is already available
    if (window.Stimulus) {
      setupHandler();
    } else {
      // Wait for Stimulus to be available
      const checkStimulus = () => {
        if (window.Stimulus) {
          setupHandler();
        } else {
          setTimeout(checkStimulus, 100);
        }
      };
      checkStimulus();
    }
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
        } else if (trimmedController && this.registeredControllers.has(trimmedController)) {
          // Validate required targets for registered controllers
          this.validateRequiredTargets(element, trimmedController);
        }
      });

      // Validate element positioning issues
      this.validateElementPositioning(element);
    });

    if (this.missingControllers.size > 0) {
      this.reportMissingControllers();
    }

    if (this.elementIssues.size > 0) {
      this.reportElementIssues();
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
        subType: 'missing-controller',
        timestamp: new Date().toISOString(),
        missingControllers: missingList,
        suggestion: `Run: rails generate stimulus_controller ${missingList[0]}`,
        details: {
          controllers: missingList,
          generatorCommands: missingList.map(name => `rails generate stimulus_controller ${name}`)
        }
      });
    } else {
      // Fallback to console
      console.error('🔴 Missing Stimulus Controllers:', missingList);
      console.info('💡 Generate missing controllers:', missingList.map(name =>
        `rails generate stimulus_controller ${name}`
      ).join('\n'));
    }
  }

  private validateRequiredTargets(controllerElement: Element, controllerName: string): void {
    try {
      const stimulus = window.Stimulus as any;
      if (stimulus?.router?.modulesByIdentifier) {
        const module = stimulus.router.modulesByIdentifier.get(controllerName);
        if (module) {
          const controllerClass = module.definition.controllerConstructor;

          const definedTargets = controllerClass.targets || [];
          const missingTargets: string[] = [];
          const outOfScopeTargets: string[] = [];

          // Get optional targets by checking for hasXXXTarget properties
          const optionalTargets = this.getOptionalTargets(controllerClass);

          definedTargets.forEach((targetName: string) => {
            // Skip validation for optional targets
            if (optionalTargets.has(targetName)) {
              return;
            }

            const targetSelector = `[data-${controllerName}-target="${targetName}"]`;
            const targetElement = controllerElement.querySelector(targetSelector);

            if (!targetElement) {
              // Check if target exists globally but outside controller scope
              const globalTargetElement = document.querySelector(targetSelector);
              if (globalTargetElement) {
                outOfScopeTargets.push(targetName);
              } else {
                missingTargets.push(targetName);
              }
            }
          });

          if (missingTargets.length > 0) {
            this.reportMissingTargets(controllerName, missingTargets, controllerElement);
          }

          if (outOfScopeTargets.length > 0) {
            this.reportOutOfScopeTargets(controllerName, outOfScopeTargets, controllerElement);
          }
        }
      }
    } catch (error) {
      console.warn(`Could not validate targets for controller ${controllerName}:`, error);
    }
  }

  private getOptionalTargets(controllerClass: any): Set<string> {
    const optionalTargets = new Set<string>();

    try {
      // Get defined targets
      const definedTargets = controllerClass.targets || [];

      definedTargets.forEach((targetName: string) => {
        // Convert target name to hasXXXTarget property name
        const capitalizedTarget = targetName.charAt(0).toUpperCase() + targetName.slice(1);
        const hasTargetProperty = `has${capitalizedTarget}Target`;

        // Check if hasXXXTarget is declared as a property on the class
        // This indicates the target is optional
        if (hasTargetProperty in controllerClass.prototype ||
            Object.getOwnPropertyDescriptor(controllerClass.prototype, hasTargetProperty) ||
            Object.hasOwnProperty.call(controllerClass.prototype, hasTargetProperty)) {
          optionalTargets.add(targetName);
        }
      });
    } catch (error) {
      console.warn('Could not analyze controller for optional targets:', error);
    }

    return optionalTargets;
  }

  private validateElementPositioning(controllerElement: Element): void {
    const controllerName = controllerElement.getAttribute('data-controller')?.split(' ')[0];
    if (!controllerName) return;

    const issues: string[] = [];

    this.checkCommonSelectors(controllerElement, controllerName, issues);

    if (issues.length > 0) {
      this.elementIssues.set(controllerName, issues);
    }
  }

  private checkCommonSelectors(element: Element, controllerName: string, issues: string[]): void {
    const relevantIds: string[] = [];

    relevantIds.push(`${controllerName}-input`, `${controllerName}-button`, `${controllerName}-form`);

    relevantIds.forEach(id => {
      const globalElement = document.getElementById(id);
      if (globalElement) {
        const isInScope = globalElement === element || element.contains(globalElement);

        if (!isInScope) {
          issues.push(`Element #${id} exists but outside controller scope`);
        }
      }
    });
  }

  private interceptActionClicks(): void {
    document.addEventListener('click', (event) => {
      const target = event.target as Element;
      if (!target) return;

      const actionElement = target.closest('[data-action]');
      if (!actionElement) return;

      const actions = actionElement.getAttribute('data-action')?.split(' ') || [];

      actions.forEach(action => {
        const controllerMatch = action.match(/([\w-]+)#([\w-]+)/);
        if (controllerMatch) {
          const controllerName = controllerMatch[1];
          const methodName = controllerMatch[2];

          if (!this.registeredControllers.has(controllerName)) {
            this.reportMissingActionController(controllerName, action, actionElement);
            return;
          }

          const controllerElement = actionElement.closest(`[data-controller*="${controllerName}"]`);
          if (!controllerElement) {
            this.reportMissingControllerScope(controllerName, action, actionElement);
            return;
          }

          this.checkMethodExists(controllerName, methodName, action, actionElement);
        }
      });
    }, true);
  }

  private reportMissingTargets(controllerName: string, missingTargets: string[], controllerElement: Element): void {
    if (window.errorHandler) {
      const targetList = missingTargets.join(', ');
      const targetExamples = missingTargets.map(target =>
        `<div data-${controllerName}-target="${target}">...</div>`
      ).join('\n');

      window.errorHandler.handleError({
        message: `Stimulus controller "${controllerName}" requires missing target elements: ${targetList}`,
        type: 'stimulus',
        subType: 'missing-target',
        controllerName,
        missingTargets,
        elementInfo: this.getElementInfo(controllerElement),
        timestamp: new Date().toISOString(),
        suggestion: `Add the required target elements to the DOM within the controller scope, or make them optional by adding ` +
          `'declare readonly has${missingTargets.map(t => t.charAt(0).toUpperCase() + t.slice(1)).join('Target: boolean, declare readonly has')}Target: boolean' to the controller`,
        details: {
          errorType: 'Missing Required Targets',
          controllerName,
          missingTargets,
          requiredElements: targetExamples,
          elementInfo: this.getElementInfo(controllerElement),
          description: `The controller "${controllerName}" defines targets [${targetList}] but these elements are not found in the DOM within the controller scope`
        }
      });
    }
  }

  private reportOutOfScopeTargets(controllerName: string, outOfScopeTargets: string[], controllerElement: Element): void {
    if (window.errorHandler) {
      const targetList = outOfScopeTargets.join(', ');

      window.errorHandler.handleError({
        message: `Stimulus controller "${controllerName}" targets exist but are outside controller scope: ${targetList}`,
        type: 'stimulus',
        subType: 'target-scope-error',
        controllerName,
        outOfScopeTargets,
        elementInfo: this.getElementInfo(controllerElement),
        timestamp: new Date().toISOString(),
        suggestion: `Move target elements inside controller scope or expand controller scope to include targets`,
        details: {
          errorType: 'Targets Outside Controller Scope',
          controllerName,
          outOfScopeTargets,
          elementInfo: this.getElementInfo(controllerElement),
          description: `The controller "${controllerName}" defines targets [${targetList}] and these elements exist in the DOM but are outside the controller scope`,
          solution: `Either move the target elements inside the controller scope, or expand the controller scope to include ` +
            `the targets by moving the data-controller attribute to a parent element that contains both the controller logic and the target elements.`
        }
      });
    }
  }

  private reportMissingActionController(controllerName: string, action: string, element: Element): void {
    if (window.errorHandler) {
      window.errorHandler.handleError({
        message: `User clicked action "${action}" but controller "${controllerName}" is not registered`,
        type: 'stimulus',
        subType: 'action-click',
        controllerName,
        action,
        elementInfo: this.getElementInfo(element),
        timestamp: new Date().toISOString(),
        suggestion: `Run: rails generate stimulus_controller ${controllerName}`,
        details: {
          errorType: 'Missing Controller on Action Click',
          controllerName,
          action,
          elementInfo: this.getElementInfo(element),
          description: 'User attempted to trigger an action but the required controller is not registered'
        }
      });
    }
  }

  private reportMissingControllerScope(controllerName: string, action: string, element: Element): void {
    if (window.errorHandler) {
      window.errorHandler.handleError({
        message: `User clicked action "${action}" but no "${controllerName}" controller found in parent scope`,
        type: 'stimulus',
        subType: 'scope-error',
        controllerName,
        action,
        elementInfo: this.getElementInfo(element),
        timestamp: new Date().toISOString(),
        suggestion: `Add data-controller="${controllerName}" to a parent element or move this element inside the controller scope`,
        details: {
          errorType: 'Controller Scope Missing',
          controllerName,
          action,
          elementInfo: this.getElementInfo(element),
          description: 'Action element is not within the scope of its target controller',
          solution: `Wrap the element with <div data-controller="${controllerName}">...</div>`
        }
      });
    }
  }

  private checkMethodExists(controllerName: string, methodName: string, action: string, element: Element): void {
    try {
      // Get the actual controller instance from Stimulus
      const stimulus = window.Stimulus as any;
      if (stimulus?.router?.modulesByIdentifier) {
        const module = stimulus.router.modulesByIdentifier.get(controllerName);
        if (module) {
          const controllerClass = module.definition.controllerConstructor;
          const instance = new controllerClass();

          // Check if method exists and is callable
          if (typeof instance[methodName] !== 'function') {
            this.reportMissingMethod(controllerName, methodName, action, element);
          }
        }
      }
    } catch (_error) {
      // If we can't instantiate the controller, try alternative approach
      this.checkMethodExistsAlternative(controllerName, methodName, action, element);
    }
  }

  private checkMethodExistsAlternative(controllerName: string, methodName: string, action: string, element: Element): void {
    // Try to get controller constructor directly
    try {
      const stimulus = window.Stimulus as any;
      if (stimulus?.router?.modulesByIdentifier) {
        const module = stimulus.router.modulesByIdentifier.get(controllerName);
        if (module) {
          const controllerClass = module.definition.controllerConstructor;

          // Check prototype for method
          if (!controllerClass.prototype[methodName] || typeof controllerClass.prototype[methodName] !== 'function') {
            this.reportMissingMethod(controllerName, methodName, action, element);
          }
        }
      }
    } catch (error) {
      console.warn(`Could not validate method existence for ${controllerName}#${methodName}:`, error);
    }
  }

  private reportMissingMethod(controllerName: string, methodName: string, action: string, element: Element): void {
    if (window.errorHandler) {
      window.errorHandler.handleError({
        message: `User clicked action "${action}" but method "${methodName}" does not exist in controller "${controllerName}"`,
        type: 'stimulus',
        subType: 'method-not-found',
        controllerName,
        methodName,
        action,
        elementInfo: this.getElementInfo(element),
        timestamp: new Date().toISOString(),
        suggestion: `Add method "${methodName}" to the ${controllerName} controller or fix the action name`,
        details: {
          errorType: 'Method Not Found',
          controllerName,
          methodName,
          action,
          elementInfo: this.getElementInfo(element),
          description: `The method "${methodName}" was called but does not exist in the controller`,
          solution: `Add the method to your controller:\n\n${methodName}(): void {\n  // Your implementation here\n}`
        }
      });
    }
  }

  private reportElementIssues(): void {
    const allIssues: string[] = [];
    const detailedIssues: { [key: string]: string[] } = {};

    this.elementIssues.forEach((issues, controllerName) => {
      allIssues.push(`${controllerName}: ${issues.join(', ')}`);
      detailedIssues[controllerName] = issues;
    });

    if (window.errorHandler) {
      window.errorHandler.handleError({
        message: `Stimulus element positioning issues detected`,
        type: 'stimulus',
        subType: 'positioning-issues',
        positioningIssues: allIssues,
        timestamp: new Date().toISOString(),
        suggestion: 'Consider using data-targets or moving elements inside controller scope',
        details: {
          errorType: 'Element Positioning Issues',
          controllers: Object.keys(detailedIssues),
          issuesByController: detailedIssues,
          totalIssues: allIssues.length,
          description: 'Some elements are referenced by controllers but exist outside their scope',
          possibleSolutions: [
            'Move elements inside controller scope',
            'Use data-targets for external elements',
            'Check controller data-controller attribute placement'
          ]
        }
      });
    }

    this.elementIssues.clear();
  }

  private getElementInfo(element: Element): object {
    return {
      tagName: element.tagName.toLowerCase(),
      id: element.id || 'no-id',
      className: element.className || 'no-class',
      textContent: (element.textContent || '').substring(0, 50)
    };
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
    this.elementIssues.clear();
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
