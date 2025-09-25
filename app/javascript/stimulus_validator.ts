// Stimulus Controller Validator
// Checks for missing stimulus controllers referenced in views

class StimulusValidator {
  private registeredControllers: Set<string> = new Set();
  private missingControllers: Set<string> = new Set();
  private hasReported: boolean = false;
  private elementIssues: Map<string, string[]> = new Map();

  constructor() {
    this.initValidator();
  }

  private initValidator(): void {
    // Only run in development environment
    if (this.isDevelopment()) {
      this.collectRegisteredControllers();
      this.validateOnDOMReady();
      this.interceptActionClicks();
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

  // 新增：验证元素位置问题
  private validateElementPositioning(controllerElement: Element): void {
    const controllerName = controllerElement.getAttribute('data-controller')?.split(' ')[0];
    if (!controllerName) return;

    const issues: string[] = [];

    // 检查常见的选择器问题
    this.checkCommonSelectors(controllerElement, controllerName, issues);
    
    // 检查 target 元素
    this.checkTargetElements(controllerElement, controllerName, issues);

    if (issues.length > 0) {
      this.elementIssues.set(controllerName, issues);
    }
  }

  private checkCommonSelectors(element: Element, controllerName: string, issues: string[]): void {
    // 根据控制器类型检查相关的元素
    let relevantIds: string[] = [];
    
    // 基本模式 - 所有控制器都检查
    relevantIds.push(`${controllerName}-input`, `${controllerName}-button`, `${controllerName}-form`);
    
    // 特定控制器的特定元素
    if (controllerName === 'chatroom') {
      relevantIds.push('message-input', 'send-button', 'messages', 'username-input', 'save-username');
    } else if (controllerName === 'clipboard') {
      // clipboard控制器通常是独立的，不需要检查额外元素
    }
    // 可以在这里为其他控制器添加特定的元素检查

    relevantIds.forEach(id => {
      const globalElement = document.getElementById(id);
      if (globalElement) {
        // 检查元素是否在控制器作用域内
        const isInScope = globalElement === element || element.contains(globalElement);
        
        if (!isInScope) {
          issues.push(`Element #${id} exists but outside controller scope`);
        }
      }
    });
  }

  private checkTargetElements(element: Element, controllerName: string, issues: string[]): void {
    // 检查 data-action 中引用的元素是否存在
    const actionElements = element.querySelectorAll('[data-action]');
    
    actionElements.forEach(actionEl => {
      const actions = actionEl.getAttribute('data-action')?.split(' ') || [];
      
      actions.forEach(action => {
        const match = action.match(new RegExp(`${controllerName}#([\\w-]+)`));
        if (match) {
          const methodName = match[1];
          // 检查这个元素是否容易找到
          if (!actionEl.id && !actionEl.getAttribute(`data-${controllerName}-target`)) {
            issues.push(`Action element for ${methodName} has no ID or target, may be hard to reference`);
          }
        }
      });
    });
  }

  // 新增：拦截用户点击，检查控制器是否存在
  private interceptActionClicks(): void {
    document.addEventListener('click', (event) => {
      const target = event.target as Element;
      if (!target) return;

      const actionElement = target.closest('[data-action]');
      if (!actionElement) return;

      const actions = actionElement.getAttribute('data-action')?.split(' ') || [];
      
      actions.forEach(action => {
        const controllerMatch = action.match(/([\w-]+)#\w+/);
        if (controllerMatch) {
          const controllerName = controllerMatch[1];
          
          // 检查控制器是否存在
          if (!this.registeredControllers.has(controllerName)) {
            this.reportMissingActionController(controllerName, action, actionElement);
            return;
          }

          // 检查控制器是否在正确的作用域内
          const controllerElement = actionElement.closest(`[data-controller*="${controllerName}"]`);
          if (!controllerElement) {
            this.reportMissingControllerScope(controllerName, action, actionElement);
          }
        }
      });
    }, true); // 使用 capture 阶段确保能拦截到
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

    // 清除已报告的问题
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

  // 新增：手动检查特定控制器的元素问题
  public checkControllerElements(controllerName: string): string[] {
    const elements = document.querySelectorAll(`[data-controller*="${controllerName}"]`);
    const allIssues: string[] = [];
    
    elements.forEach(element => {
      const issues: string[] = [];
      this.checkCommonSelectors(element, controllerName, issues);
      this.checkTargetElements(element, controllerName, issues);
      allIssues.push(...issues);
    });
    
    return allIssues;
  }
}

// Note: Global types are declared in types/global.d.ts

// Initialize validator
if (typeof window !== 'undefined') {
  window.stimulusValidator = new StimulusValidator();
}

export default StimulusValidator;
