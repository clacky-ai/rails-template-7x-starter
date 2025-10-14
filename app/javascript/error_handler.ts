// Enhanced JavaScript Error Handler with Persistent Status Bar
// Provides user-friendly error monitoring with permanent visibility

import { SourceMapConsumer } from 'source-map-js'

// Error type definitions
type ErrorType = 'javascript' | 'interaction' | 'network' | 'promise' | 'http' | 'actioncable' | 'manual' | 'stimulus' | 'asyncjob';

// Base error info interface
interface BaseErrorInfo {
  message: string;
  type: ErrorType;
  timestamp: string;
  filename?: string;
  lineno?: number;
  colno?: number;
  error?: Error;
}

// JavaScript/Interaction error info
interface JavaScriptErrorInfo extends BaseErrorInfo {
  type: 'javascript' | 'interaction';
  filename?: string;
  lineno?: number;
  colno?: number;
  error?: Error;
}

// Promise error info
interface PromiseErrorInfo extends BaseErrorInfo {
  type: 'promise';
  error?: any;
}

// Network/HTTP error info
interface NetworkErrorInfo extends BaseErrorInfo {
  type: 'network' | 'http';
  url?: string;
  method?: string;
  status?: number;
  responseBody?: string;
  jsonError?: any;
}

// ActionCable error info
interface ActionCableErrorInfo extends BaseErrorInfo {
  type: 'actioncable';
  channel?: string;
  action?: string;
  details?: any;
}

// AsyncJob error info
interface AsyncJobErrorInfo extends BaseErrorInfo {
  type: 'asyncjob';
  job_class?: string;
  job_id?: string;
  queue?: string;
  exception_class?: string;
  backtrace?: string;
  details?: any;
}

// Manual error info
interface ManualErrorInfo extends BaseErrorInfo {
  type: 'manual';
  [key: string]: any; // Allow additional context properties
}

// Stimulus error info
interface StimulusErrorInfo extends BaseErrorInfo {
  type: 'stimulus';
  missingControllers?: string[];
  missingTargets?: string[];
  outOfScopeTargets?: string[];
  suggestion?: string;
  details?: any;
  subType?: 'missing-controller' | 'scope-error' | 'positioning-issues' | 'action-click' | 'missing-target' | 'missing-action' | 'method-not-found' | 'target-scope-error';
  controllerName?: string;
  action?: string;
  methodName?: string;
  elementInfo?: any;
  positioningIssues?: string[];
}

// Union type for all possible error info types
type ErrorInfo = JavaScriptErrorInfo | PromiseErrorInfo | NetworkErrorInfo | ActionCableErrorInfo | AsyncJobErrorInfo | ManualErrorInfo | StimulusErrorInfo;

// Unified error detail configuration system
interface ErrorDetailConfig {
  htmlFormatter: (value: any, key: string) => string;
  textFormatter: (value: any, key: string) => string;
  label: string;
  priority?: number; // Higher priority fields appear first
  condition?: (error: StoredError) => boolean; // Optional condition to show this field
}

interface ErrorTypeConfig {
  icon: string;
  fields: { [key: string]: ErrorDetailConfig };
}

// Centralized error type configurations
const ERROR_TYPE_CONFIGS: { [key: string]: ErrorTypeConfig } = {
  javascript: {
    icon: '⚠️',
    fields: {
      filename: {
        label: 'File',
        priority: 10,
        htmlFormatter: (value: string) => `<div class="my-1"><strong>File:</strong> ${value}</div>`,
        textFormatter: (value: string) => `File: ${value}`
      },
      lineno: {
        label: 'Line',
        priority: 9,
        htmlFormatter: (value: number) => `<div class="mb-1"><strong>Line:</strong> ${value}</div>`,
        textFormatter: (value: number) => `Line: ${value}`
      },
      'error.stack': {
        label: 'Stack Trace',
        priority: 1,
        condition: (error) => error.error?.stack,
        htmlFormatter: (value: string) => {
          const preClass = 'text-xs bg-gray-800 p-3 rounded overflow-x-auto whitespace-pre-wrap leading-relaxed';
          return `<div class=""><div class="mb-1"><strong>Stack Trace:</strong></div><pre class="${preClass}">${value}</pre></div>`;
        },
        textFormatter: (value: string) => `Stack Trace:\n${value}`
      }
    }
  },
  interaction: {
    icon: '🔴',
    fields: {
      filename: {
        label: 'File',
        priority: 10,
        htmlFormatter: (value: string) => `<div class="mb-1"><strong>File:</strong> ${value}</div>`,
        textFormatter: (value: string) => `File: ${value}`
      },
      lineno: {
        label: 'Line',
        priority: 9,
        htmlFormatter: (value: number) => `<div class="mb-1"><strong>Line:</strong> ${value}</div>`,
        textFormatter: (value: number) => `Line: ${value}`
      }
    }
  },
  network: {
    icon: '📡',
    fields: {
      method: {
        label: 'Method',
        priority: 10,
        htmlFormatter: (value: string) => `<div class="mb-1"><strong>Method:</strong> ${value}</div>`,
        textFormatter: (value: string) => `Method: ${value}`
      },
      status: {
        label: 'Status Code',
        priority: 9,
        htmlFormatter: (value: number) => `<div class="mb-1"><strong>Status Code:</strong> ${value}</div>`,
        textFormatter: (value: number) => `Status Code: ${value}`
      },
      jsonError: {
        label: 'JSON Error Details',
        priority: 5,
        condition: (error) => !!error.jsonError,
        htmlFormatter: (value: any) => {
          const preClass = 'text-xs bg-gray-800 p-3 rounded overflow-x-auto whitespace-pre-wrap leading-relaxed';
          return `<div class="mb-3"><div class="mb-1"><strong>JSON Error Details:</strong></div><pre class="${preClass}">${JSON.stringify(value, null, 2)}</pre></div>`;
        },
        textFormatter: (value: any) => `JSON Error Details:\n${JSON.stringify(value, null, 2)}`
      },
      responseBody: {
        label: 'Response Body',
        priority: 4,
        condition: (error) => {
          return !!(error.responseBody && (!error.jsonError || error.responseBody !== JSON.stringify(error.jsonError, null, 2)));
        },
        htmlFormatter: (value: string) => {
          const preClass = 'text-xs bg-gray-800 p-3 rounded overflow-x-auto whitespace-pre-wrap leading-relaxed';
          return `<div class="mb-3"><div class="mb-1"><strong>Response Body:</strong></div><pre class="${preClass}">${value}</pre></div>`;
        },
        textFormatter: (value: string) => `Response Body:\n${value}`
      }
    }
  },
  http: {
    icon: '🌐',
    fields: {
      method: {
        label: 'Method',
        priority: 10,
        htmlFormatter: (value: string) => `<div class="mb-1"><strong>Method:</strong> ${value}</div>`,
        textFormatter: (value: string) => `Method: ${value}`
      },
      status: {
        label: 'Status Code',
        priority: 9,
        htmlFormatter: (value: number) => `<div class="mb-1"><strong>Status Code:</strong> ${value}</div>`,
        textFormatter: (value: number) => `Status Code: ${value}`
      },
      jsonError: {
        label: 'JSON Error Details',
        priority: 5,
        condition: (error) => !!error.jsonError,
        htmlFormatter: (value: any) => {
          const preClass = 'text-xs bg-gray-800 p-3 rounded overflow-x-auto whitespace-pre-wrap leading-relaxed';
          return `<div class="mb-3"><div class="mb-1"><strong>JSON Error Details:</strong></div><pre class="${preClass}">${JSON.stringify(value, null, 2)}</pre></div>`;
        },
        textFormatter: (value: any) => `JSON Error Details:\n${JSON.stringify(value, null, 2)}`
      },
      responseBody: {
        label: 'Response Body',
        priority: 4,
        condition: (error) => {
          return !!(error.responseBody && (!error.jsonError || error.responseBody !== JSON.stringify(error.jsonError, null, 2)));
        },
        htmlFormatter: (value: string) => {
          const preClass = 'text-xs bg-gray-800 p-3 rounded overflow-x-auto whitespace-pre-wrap leading-relaxed';
          return `<div class="mb-3"><div class="mb-1"><strong>Response Body:</strong></div><pre class="${preClass}">${value}</pre></div>`;
        },
        textFormatter: (value: string) => `Response Body:\n${value}`
      }
    }
  },
  promise: {
    icon: '⚡',
    fields: {
      'error.stack': {
        label: 'Stack Trace',
        priority: 1,
        condition: (error) => error.error?.stack,
        htmlFormatter: (value: string) => {
          const preClass = 'text-xs bg-gray-800 p-3 rounded overflow-x-auto whitespace-pre-wrap leading-relaxed';
          return `<div class="mb-3"><div class="mb-1"><strong>Stack Trace:</strong></div><pre class="${preClass}">${value}</pre></div>`;
        },
        textFormatter: (value: string) => `Stack Trace:\n${value}`
      }
    }
  },
  actioncable: {
    icon: '🔌',
    fields: {
      channel: {
        label: 'Channel',
        priority: 10,
        htmlFormatter: (value: string) => `<div class="mb-1"><strong>Channel:</strong> ${value}</div>`,
        textFormatter: (value: string) => `Channel: ${value}`
      },
      action: {
        label: 'Action',
        priority: 9,
        htmlFormatter: (value: string) => `<div class="mb-1"><strong>Action:</strong> ${value}</div>`,
        textFormatter: (value: string) => `Action: ${value}`
      },
      details: {
        label: 'Channel Error Details',
        priority: 5,
        condition: (error) => !!error.details,
        htmlFormatter: (value: any) => {
          const preClass = 'text-xs bg-gray-800 p-3 rounded overflow-x-auto whitespace-pre-wrap leading-relaxed';
          return `<div class="mb-3"><div class="mb-1"><strong>Channel Error Details:</strong></div><pre class="${preClass}">${JSON.stringify(value, null, 2)}</pre></div>`;
        },
        textFormatter: (value: any) => `Channel Error Details:\n${JSON.stringify(value, null, 2)}`
      }
    }
  },
  stimulus: {
    icon: '🎯',
    fields: {
      subType: {
        label: 'Stimulus Error Type',
        priority: 10,
        htmlFormatter: (value: string) => `<div class="mb-1"><strong>Stimulus Error Type:</strong> ${value}</div>`,
        textFormatter: (value: string) => `Stimulus Error Type: ${value}`
      },
      controllerName: {
        label: 'Controller',
        priority: 9,
        htmlFormatter: (value: string) => `<div class="mb-1"><strong>Controller:</strong> ${value}</div>`,
        textFormatter: (value: string) => `Controller: ${value}`
      },
      action: {
        label: 'Action',
        priority: 8,
        htmlFormatter: (value: string) => `<div class="mb-1"><strong>Action:</strong> ${value}</div>`,
        textFormatter: (value: string) => `Action: ${value}`
      },
      missingControllers: {
        label: 'Missing Controllers',
        priority: 7,
        condition: (error) => !!(error.missingControllers && error.missingControllers.length > 0),
        htmlFormatter: (value: string[]) => `<div class="mb-3"><strong>Missing Controllers:</strong> ${value.join(', ')}</div>`,
        textFormatter: (value: string[]) => `Missing Controllers: ${value.join(', ')}`
      },
      positioningIssues: {
        label: 'Positioning Issues',
        priority: 6,
        condition: (error) => !!(error.positioningIssues && error.positioningIssues.length > 0),
        htmlFormatter: (value: string[]) => {
          const ulClass = 'text-xs list-disc list-inside bg-gray-800 p-3 rounded space-y-1';
          const items = value.map((issue: string) => `<li class="leading-relaxed">${issue}</li>`).join('');
          return `<div class="mb-3"><div class="mb-1"><strong>Positioning Issues:</strong></div><ul class="${ulClass}">${items}</ul></div>`;
        },
        textFormatter: (value: string[]) => `Positioning Issues:\n${value.map((issue: string) => `  - ${issue}`).join('\n')}`
      },
      elementInfo: {
        label: 'Element Info',
        priority: 5,
        condition: (error) => !!error.elementInfo,
        htmlFormatter: (value: any) => {
          const preClass = 'text-xs bg-gray-800 p-3 rounded overflow-x-auto whitespace-pre-wrap leading-relaxed';
          return `<div class="mb-3"><div class="mb-1"><strong>Element Info:</strong></div><pre class="${preClass}">${JSON.stringify(value, null, 2)}</pre></div>`;
        },
        textFormatter: (value: any) => `Element Info:\n${JSON.stringify(value, null, 2)}`
      },
      suggestion: {
        label: '💡 Suggestion',
        priority: 3,
        htmlFormatter: (value: string) => {
          const divClass = 'text-sm bg-blue-900 text-blue-200 p-3 rounded leading-relaxed';
          return `<div class="mb-3"><div class="mb-1"><strong>💡 Suggestion:</strong></div><div class="${divClass}">${value}</div></div>`;
        },
        textFormatter: (value: string) => `Suggestion: ${value}`
      },
      details: {
        label: 'Detailed Information',
        priority: 2,
        condition: (error) => !!error.details,
        htmlFormatter: (value: any) => {
          const preClass = 'text-xs bg-gray-800 p-3 rounded overflow-x-auto whitespace-pre-wrap leading-relaxed';
          return `<div class="mb-3"><div class="mb-1"><strong>Detailed Information:</strong></div><pre class="${preClass}">${JSON.stringify(value, null, 2)}</pre></div>`;
        },
        textFormatter: (value: any) => `Detailed Information:\n${JSON.stringify(value, null, 2)}`
      }
    }
  },
  asyncjob: {
    icon: '⚙️',
    fields: {
      job_class: {
        label: 'Job Class',
        priority: 10,
        htmlFormatter: (value: string) => `<div class="mb-1"><strong>Job Class:</strong> ${value}</div>`,
        textFormatter: (value: string) => `Job Class: ${value}`
      },
      queue: {
        label: 'Queue',
        priority: 9,
        htmlFormatter: (value: string) => `<div class="mb-1"><strong>Queue:</strong> ${value}</div>`,
        textFormatter: (value: string) => `Queue: ${value}`
      },
      exception_class: {
        label: 'Exception',
        priority: 8,
        htmlFormatter: (value: string) => `<div class="mb-1"><strong>Exception:</strong> ${value}</div>`,
        textFormatter: (value: string) => `Exception: ${value}`
      },
      backtrace: {
        label: 'Backtrace',
        priority: 5,
        condition: (error) => !!error.backtrace,
        htmlFormatter: (value: string) => {
          const preClass = 'text-xs bg-gray-800 p-3 rounded overflow-x-auto whitespace-pre-wrap leading-relaxed';
          return `<div class="mb-3"><div class="mb-1"><strong>Backtrace:</strong></div><pre class="${preClass}">${value}</pre></div>`;
        },
        textFormatter: (value: string) => `Backtrace:\n${value}`
      }
    }
  },
  manual: {
    icon: '📝',
    fields: {
      // Manual errors can have dynamic fields, so we'll handle them in the generic formatter
    }
  }
};

// Stored error interface (includes additional properties added by the handler)
interface StoredError {
  id: string;
  message: string;
  type: ErrorType;
  timestamp: string;
  count: number;
  lastOccurred: string;
  // Optional properties that may exist on different error types
  filename?: string;
  lineno?: number;
  colno?: number;
  error?: Error | any;
  url?: string;
  method?: string;
  status?: number;
  responseBody?: string;
  jsonError?: any;
  channel?: string;
  action?: string;
  details?: any;
  missingControllers?: string[];
  suggestion?: string;
  [key: string]: any; // Allow additional properties for manual errors
}

// Error counts interface
interface ErrorCounts {
  javascript: number;
  interaction: number;
  network: number;
  promise: number;
  http: number;
  actioncable: number;
  asyncjob: number;
  manual?: number;
  stimulus?: number;
}

class ErrorHandler {
  private errors: StoredError[] = [];
  private maxErrors: number = 50;
  private isExpanded: boolean = false;
  private statusBar: HTMLElement | null = null;
  private errorList: HTMLElement | null = null;
  private isInteractionError: boolean = false;
  private errorCounts: ErrorCounts = {
    javascript: 0,
    interaction: 0,
    network: 0,
    promise: 0,
    http: 0,
    actioncable: 0,
    asyncjob: 0,
    manual: 0,
    stimulus: 0
  };
  private recentErrorsDebounce: Map<string, number> = new Map();
  private debounceTime: number = 1000;
  private uiReady: boolean = false;
  private pendingUIUpdates: boolean = false;
  private hasShownFirstError: boolean = false;
  private lastInteractionTime: number = 0;
  private originalConsoleError: typeof console.error;
  private sourceMapCache: Map<string, SourceMapConsumer> = new Map();
  private sourceMapPending: Map<string, Promise<SourceMapConsumer | null>> = new Map();

  constructor() {
    // Save original console.error before any interception
    this.originalConsoleError = console.error.bind(console);
    this.init();
  }

  init() {
    // Setup error handlers immediately
    this.setupGlobalErrorHandlers();
    this.setupInteractionTracking();

    // Defer UI creation until DOM is ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.initUI());
    } else {
      this.initUI();
    }
  }

  initUI() {
    console.log('Initializing UI...');
    this.createStatusBar();
    this.uiReady = true;
    this.updateStatusBar();

    // If there were errors before UI was ready, update now
    if (this.pendingUIUpdates) {
      this.updateErrorList();
      this.showStatusBar();
      this.pendingUIUpdates = false;

      // Auto-expand logic disabled
      // if (!this.hasShownFirstError && this.errors.length > 0) {
      //   this.hasShownFirstError = true;
      //   this.autoExpandErrorDetails();
      // }
    }
    console.log('UI initialization complete.');
  }

  createStatusBar() {
    console.log('Creating status bar... document.body exists?', !!document.body);
    // Create persistent bottom status bar
    const statusBar = document.createElement('div');
    statusBar.id = 'js-error-status-bar';
    statusBar.className = 'fixed bottom-0 left-0 right-0 bg-gray-900 text-white z-50 border-t border-gray-700 transition-all duration-300';
    statusBar.style.display = 'none'; // Initially hidden until first error

    statusBar.innerHTML = `
      <div class="flex items-center justify-between px-4 py-2 h-10">
        <div class="flex items-center space-x-4">
          <div id="error-summary" class="flex items-center space-x-3 text-sm">
            <!-- Error counts will be inserted here -->
          </div>
          <div id="error-tips" class="relative" style="display: none;">
            <span class="cursor-help text-gray-500 hover:text-gray-300 transition-colors duration-200 text-sm opacity-60 hover:opacity-100">💡</span>
            <div class="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-3 py-2 bg-gray-800 text-white text-xs
                      rounded-lg shadow-lg border border-gray-600 whitespace-nowrap opacity-0 pointer-events-none
                      transition-opacity duration-200 tooltip">
              Send to chatbox for repair (90% cases) or ignore if browser extension (10% cases)
              <div class="absolute top-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-t-4
                        border-transparent border-t-gray-800"></div>
            </div>
          </div>
        </div>
        <div class="flex items-center space-x-2">
          <button id="copy-all-errors" class="text-yellow-400 hover:text-yellow-300 text-sm px-2 py-1 rounded" style="display: none;">
            Copy Error
          </button>
          <button id="toggle-errors" class="text-blue-400 hover:text-blue-300 text-sm px-2 py-1 rounded">
            <span id="toggle-text">Show</span>
            <span id="toggle-icon">↑</span>
          </button>
          <button id="clear-all-errors" class="text-red-400 hover:text-red-300 text-sm px-2 py-1 rounded">
            Clear
          </button>
        </div>
      </div>
      <div id="error-details" class="border-t border-gray-700 bg-gray-800 max-h-64 overflow-y-auto" style="display: none;">
        <div id="error-list" class="p-4 space-y-2">
          <!-- Error list will be inserted here -->
        </div>
      </div>
    `;

    document.body.appendChild(statusBar);
    this.statusBar = statusBar;
    this.errorList = document.getElementById('error-list');
    console.log('Status bar created and appended. ID:', statusBar.id);

    this.setupStatusBarEvents();
  }

  setupStatusBarEvents() {
    // Toggle expand/collapse
    document.getElementById('toggle-errors')?.addEventListener('click', () => {
      this.toggleErrorDetails();
    });

    // Copy all errors
    document.getElementById('copy-all-errors')?.addEventListener('click', () => {
      this.copyAllErrorsToClipboard();
    });

    // Clear all errors
    document.getElementById('clear-all-errors')?.addEventListener('click', () => {
      this.clearAllErrors();
    });

    // Setup tooltip hover events
    this.setupTooltipEvents();
  }

  setupTooltipEvents() {
    const tipsContainer = document.getElementById('error-tips');
    if (!tipsContainer) return;

    const icon = tipsContainer.querySelector('span');
    const tooltip = tipsContainer.querySelector('.tooltip');

    if (icon && tooltip) {
      // Show tooltip on hover
      icon.addEventListener('mouseenter', () => {
        tooltip.classList.remove('opacity-0', 'pointer-events-none');
        tooltip.classList.add('opacity-100');
      });

      // Hide tooltip when not hovering
      icon.addEventListener('mouseleave', () => {
        tooltip.classList.remove('opacity-100');
        tooltip.classList.add('opacity-0', 'pointer-events-none');
      });
    }
  }

  toggleErrorDetails() {
    const details = document.getElementById('error-details');
    const toggleText = document.getElementById('toggle-text');
    const toggleIcon = document.getElementById('toggle-icon');

    if (!details || !toggleText || !toggleIcon) return;

    this.isExpanded = !this.isExpanded;

    if (this.isExpanded) {
      details.style.display = 'block';
      toggleText.textContent = 'Hide';
      toggleIcon.textContent = '↓';
    } else {
      details.style.display = 'none';
      toggleText.textContent = 'Show';
      toggleIcon.textContent = '↑';
    }
  }

  setupGlobalErrorHandlers() {
    // Intercept console.error
    console.error = (...args: any[]) => {
      // Always call original console.error first
      this.originalConsoleError(...args);

      // Extract and format error message from arguments
      let message = '';

      if (args.length === 0) return;

      // Check if first argument is a format string (contains %s, %o, %d, etc.)
      const firstArg = args[0];
      if (typeof firstArg === 'string' && /%[sodifcO]/.test(firstArg)) {
        // Format string detected - apply basic formatting
        message = firstArg;
        let argIndex = 1;

        // Replace format specifiers with actual values
        message = message.replace(/%[sodifcO]/g, (match) => {
          if (argIndex >= args.length) return match;
          const arg = args[argIndex++];

          if (arg instanceof Error) {
            return arg.message;
          } else if (typeof arg === 'object') {
            try {
              return JSON.stringify(arg);
            } catch {
              return String(arg);
            }
          }
          return String(arg);
        });
      } else {
        // No format string - join all arguments
        message = args.map(arg => {
          if (arg instanceof Error) {
            return arg.message;
          } else if (typeof arg === 'object') {
            try {
              return JSON.stringify(arg);
            } catch {
              return String(arg);
            }
          }
          return String(arg);
        }).join(' ');
      }

      // Skip if message is empty or trivial
      if (!message || message.trim().length === 0) {
        return;
      }

      // Check for duplicate using partial matching
      const isDuplicate = this.errors.some(error => {
        // Remove [console.error] prefix for comparison
        const existingMsg = error.message.replace(/^\[console\.error\]\s*/, '');
        const newMsg = message;

        // Consider it duplicate if one message contains the other
        const isSimilar = existingMsg.includes(newMsg) || newMsg.includes(existingMsg);
        const isRecent = Date.now() - new Date(error.lastOccurred).getTime() < 5000; // 5 second window

        return isSimilar && isRecent;
      });

      if (!isDuplicate) {
        // Create Error to capture stack trace if not already present
        let errorObj = args.find(arg => arg instanceof Error);
        if (!errorObj) {
          errorObj = new Error(message);
          // Remove first 2 lines from stack (Error creation and console.error wrapper)
          if (errorObj.stack) {
            const stackLines = errorObj.stack.split('\n');
            errorObj.stack = [stackLines[0], ...stackLines.slice(3)].join('\n');
          }
        }

        // Report to error handler with [console.error] prefix
        this.handleError({
          message: `[console.error] ${message}`,
          type: 'javascript',
          timestamp: new Date().toISOString(),
          error: errorObj
        });
      }
    };

    // Set window.onerror for compatibility with libraries like Stimulus that check for its existence
    if (!window.onerror) {
      window.onerror = (message: string | Event, source?: string, lineno?: number, colno?: number, error?: Error) => {
        this.originalConsoleError('🔔 window.onerror triggered:', { message, source, lineno, colno, error });
        this.handleError({
          message: typeof message === 'string' ? message : 'Script error',
          filename: source,
          lineno: lineno,
          colno: colno,
          error: error,
          type: this.isInteractionError ? 'interaction' : 'javascript',
          timestamp: new Date().toISOString()
        });
        return true; // Prevent default browser error handling
      };
    }

    // Also use addEventListener for additional error capture capabilities
    window.addEventListener('error', (event) => {
      // Only handle if not already handled by window.onerror
      if (window.onerror && typeof window.onerror === 'function') {
        // window.onerror already handled this, but we can add additional processing if needed
        return;
      }

      this.handleError({
        message: event.message,
        filename: event.filename,
        lineno: event.lineno,
        colno: event.colno,
        error: event.error,
        type: this.isInteractionError ? 'interaction' : 'javascript',
        timestamp: new Date().toISOString()
      });
    });

    // Capture unhandled promise rejections
    window.addEventListener('unhandledrejection', (event) => {
      this.handleError({
        message: event.reason?.message || 'Unhandled Promise Rejection',
        error: event.reason,
        type: 'promise',
        timestamp: new Date().toISOString()
      });
    });

    // Intercept fetch errors
    this.interceptFetch();
    // Intercept XHR errors
    this.interceptXHR();
  }

  setupInteractionTracking() {
    // Track user interactions to identify interaction-triggered errors
    ['click', 'submit', 'change', 'keydown'].forEach(eventType => {
      document.addEventListener(eventType, () => {
        this.isInteractionError = true;
        this.lastInteractionTime = Date.now();
        setTimeout(() => {
          this.isInteractionError = false;
        }, 2000); // 2 second window for interaction errors
      });
    });
  }

  interceptFetch() {
    const originalFetch = window.fetch;
    window.fetch = async (...args) => {
      try {
        const response = await originalFetch(...args);

        if (!response.ok) {
          // Extract HTTP method from request options
          const requestOptions = args[1] || {};
          const method = (requestOptions.method || 'GET').toUpperCase();

          // Try to extract response body for detailed error information
          let responseBody = null;
          let jsonError = null;

          try {
            // Clone the response to avoid consuming it
            const responseClone = response.clone();
            const contentType = response.headers.get('content-type');

            if (contentType && contentType.includes('application/json')) {
              jsonError = await responseClone.json();
              responseBody = JSON.stringify(jsonError, null, 2);
            } else {
              responseBody = await responseClone.text();
            }
          } catch (bodyError) {
            // If we can't read the body, just note that
            responseBody = 'Unable to read response body';
          }

          // Create detailed error message
          let detailedMessage = `${method} ${args[0]} - HTTP ${response.status}`;
          if (jsonError) {
            // Extract meaningful error message from JSON
            const errorMsg = jsonError.error || jsonError.message || jsonError.errors || 'Unknown error';
            detailedMessage += ` - ${errorMsg}`;
          }

          this.handleError({
            message: detailedMessage,
            url: args[0].toString(),
            method: method,
            type: response.status >= 500 ? 'http' : 'network',
            status: response.status,
            responseBody: responseBody,
            jsonError: jsonError,
            timestamp: new Date().toISOString()
          });
        }

        return response;
      } catch (error) {
        // Extract HTTP method for network errors too
        const requestOptions = args[1] || {};
        const method = (requestOptions.method || 'GET').toUpperCase();

        this.handleError({
          message: `${method} ${args[0]} - Network Error: ${(error as Error).message}`,
          url: args[0].toString(),
          method: method,
          error: error as Error,
          type: 'network',
          timestamp: new Date().toISOString()
        });
        throw error;
      }
    };
  }

  interceptXHR() {
    const originalXHROpen = XMLHttpRequest.prototype.open;
    const originalXHRSend = XMLHttpRequest.prototype.send;

    XMLHttpRequest.prototype.open = function(method: string, url: string | URL, async?: boolean, user?: string | null, password?: string | null) {
      (this as any)._errorHandler_method = method.toUpperCase();
      (this as any)._errorHandler_url = url.toString();
      return originalXHROpen.call(this, method, url, async ?? true, user, password);
    };

    XMLHttpRequest.prototype.send = function(body?: any) {
      const xhr = this as any;
      const method = xhr._errorHandler_method || 'GET';
      const url = xhr._errorHandler_url || 'unknown';

      // Set up error event listeners
      xhr.addEventListener('error', (event: Event) => {
        window.errorHandler?.handleError({
          message: `${method} ${url} - Network Error: Request failed`,
          url: url,
          method: method,
          type: 'network',
          timestamp: new Date().toISOString()
        });
      });

      xhr.addEventListener('timeout', () => {
        window.errorHandler?.handleError({
          message: `${method} ${url} - Network Error: Request timeout`,
          url: url,
          method: method,
          type: 'network',
          timestamp: new Date().toISOString()
        });
      });

      xhr.addEventListener('loadend', () => {
        if (xhr.status >= 400) {
          let responseBody = null;
          let jsonError = null;

          try {
            const contentType = xhr.getResponseHeader('content-type');
            if (contentType && contentType.includes('application/json')) {
              jsonError = JSON.parse(xhr.responseText);
              responseBody = JSON.stringify(jsonError, null, 2);
            } else {
              responseBody = xhr.responseText;
            }
          } catch (parseError) {
            responseBody = xhr.responseText || 'Unable to read response body';
          }

          // Create detailed error message
          let detailedMessage = `${method} ${url} - HTTP ${xhr.status}`;
          if (jsonError) {
            const errorMsg = jsonError.error || jsonError.message || jsonError.errors || 'Unknown error';
            detailedMessage += ` - ${errorMsg}`;
          }

          window.errorHandler?.handleError({
            message: detailedMessage,
            url: url,
            method: method,
            type: xhr.status >= 500 ? 'http' : 'network',
            status: xhr.status,
            responseBody: responseBody,
            jsonError: jsonError,
            timestamp: new Date().toISOString()
          });
        }
      });

      return originalXHRSend.call(this, body);
    };
  }

  handleError(errorInfo: ErrorInfo): void {
    // Filter out browser-specific errors we can't control
    if (this.shouldIgnoreError(errorInfo)) {
      return;
    }

    // Enrich error with source map asynchronously
    this.enrichErrorWithSourceMap(errorInfo).then(enrichedError => {
      this.processError(enrichedError);
    }).catch(err => {
      this.originalConsoleError('Failed to enrich error with source map', err);
      // Fall back to processing original error
      this.processError(errorInfo);
    });
  }

  private processError(errorInfo: ErrorInfo): void {

    // Create a debounce key for similar errors
    const debounceKey = `${errorInfo.type}_${errorInfo.message}_${errorInfo.filename}_${errorInfo.lineno}`;

    // Check if this error was recently processed (debouncing)
    if (this.recentErrorsDebounce.has(debounceKey)) {
      const lastTime = this.recentErrorsDebounce.get(debounceKey);
      if (lastTime && Date.now() - lastTime < this.debounceTime) {
        // Update existing error count instead of creating new one
        const existingError = this.findDuplicateError(errorInfo);
        if (existingError) {
          existingError.count++;
          existingError.lastOccurred = errorInfo.timestamp;
          this.updateStatusBar();
          this.updateErrorList();
        }
        return;
      }
    }

    // Set debounce timestamp
    this.recentErrorsDebounce.set(debounceKey, Date.now());

    // Check for duplicate errors
    const isDuplicate = this.findDuplicateError(errorInfo);
    if (isDuplicate) {
      isDuplicate.count++;
      isDuplicate.lastOccurred = errorInfo.timestamp;
    } else {
      // Add new error
      const error = {
        id: this.generateErrorId(),
        ...errorInfo,
        count: 1,
        lastOccurred: errorInfo.timestamp,
      };

      this.errors.unshift(error);

      // Keep only recent errors
      if (this.errors.length > this.maxErrors) {
        this.errors = this.errors.slice(0, this.maxErrors);
      }
    }

    // Update counts
    if (errorInfo.type in this.errorCounts) {
      this.errorCounts[errorInfo.type as keyof ErrorCounts]++;
    }

    // Update UI (if ready) or mark for later update
    if (this.uiReady) {
      this.updateStatusBar();
      this.updateErrorList();
      this.showStatusBar();
      this.flashNewError();

      // Auto-expand logic disabled
      // this.checkAutoExpand(errorInfo);
    } else {
      console.log('UI not ready, marking for later update');
      this.pendingUIUpdates = true;
    }

    // Clean up old debounce entries
    this.cleanupDebounceMap();
  }

  shouldIgnoreError(errorInfo: ErrorInfo): boolean {
    const ignoredPatterns = [
      // Browser extension errors
      /chrome-extension:/,
      /moz-extension:/,
      /safari-extension:/,

      // Common browser errors we can't control
      /Script error/,
      /Non-Error promise rejection captured/,
      /ResizeObserver loop limit exceeded/,
      /passive event listener/,

      // Third-party script errors
      /google-analytics/,
      /googletagmanager/,
      /facebook\.net/,
      /twitter\.com/,

      // iOS Safari specific
      /WebKitBlobResource/,
    ];

    const message = errorInfo.message || '';
    const filename = errorInfo.filename || '';

    return ignoredPatterns.some(pattern =>
      pattern.test(message) || pattern.test(filename)
    );
  }

  findDuplicateError(errorInfo: ErrorInfo): StoredError | undefined {
    return this.errors.find(error => {
      // Use partial message matching to handle variations
      const existingMsg = error.message.replace(/^\[console\.error\]\s*/, '');
      const newMsg = errorInfo.message.replace(/^\[console\.error\]\s*/, '');

      // Consider it duplicate if one message contains the other
      const messagesMatch = existingMsg.includes(newMsg) || newMsg.includes(existingMsg);
      if (!messagesMatch) return false;

      // Type matching: javascript and interaction are considered similar
      const typesMatch = error.type === errorInfo.type ||
                        (error.type === 'javascript' && errorInfo.type === 'interaction') ||
                        (error.type === 'interaction' && errorInfo.type === 'javascript');
      if (!typesMatch) return false;

      // Only check filename/lineno if both errors have them
      // If one has them and the other doesn't, still consider it a match based on message
      const bothHaveLocation = error.filename && errorInfo.filename;
      if (bothHaveLocation) {
        // If both have location info, they should match
        if (error.filename !== errorInfo.filename || error.lineno !== errorInfo.lineno) {
          return false;
        }
      }

      return true;
    });
  }

  generateErrorId() {
    return `error_${  Date.now()  }_${  Math.random().toString(36).substr(2, 9)}`;
  }

  updateStatusBar() {
    const summary = document.getElementById('error-summary');
    const copyButton = document.getElementById('copy-all-errors');
    const tipsElement = document.getElementById('error-tips');
    if (!summary) return; // UI not ready yet

    const totalErrors = this.errors.reduce((sum, error) => sum + error.count, 0);

    if (totalErrors === 0) {
      summary.innerHTML = '<span class="text-green-400">✓ No Errors</span>';
      if (copyButton) copyButton.style.display = 'none';
      if (tipsElement) tipsElement.style.display = 'none';
      return;
    }

    // Unified error display without type distinction
    summary.innerHTML = `<span class="text-red-400">🔴 Frontend code error detected (${totalErrors})</span>`;
    if (copyButton) copyButton.style.display = 'block';
    if (tipsElement) tipsElement.style.display = 'block';
  }

  updateErrorList() {
    if (!this.errorList) return; // UI not ready yet

    const listHTML = this.errors.map(error => this.createErrorItemHTML(error)).join('');
    this.errorList.innerHTML = listHTML;

    // Attach event listeners to new error items
    this.attachErrorItemListeners();
  }

  createErrorItemHTML(error: StoredError): string {
    const icon = this.getErrorIcon(error.type);
    const countText = error.count > 1 ? ` (${error.count}x)` : '';
    const timeStr = new Date(error.timestamp).toLocaleTimeString();

    return `
      <div class="flex items-start justify-between bg-gray-700 rounded p-3 error-item" data-error-id="${error.id}">
        <div class="flex items-start space-x-3 flex-1">
          <div class="text-lg">${icon}</div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center justify-between">
              <span class="font-medium text-sm text-white truncate pr-2">${this.sanitizeMessage(error.message)}</span>
              <span class="text-xs text-gray-400 whitespace-nowrap mt-1">${timeStr}${countText}</span>
            </div>
            <div class="technical-details mt-2 text-xs text-gray-500" style="display: none;">
              ${this.formatTechnicalDetails(error)}
            </div>
          </div>
        </div>
        <div class="flex items-center space-x-1 ml-3">
          <button class="copy-error text-blue-400 hover:text-blue-300 px-2 py-1 text-xs rounded" title="Copy error for chatbox">
            Copy
          </button>
          <button class="toggle-details text-gray-400 hover:text-gray-300 px-2 py-1 text-xs rounded" title="Toggle details">
            Details
          </button>
          <button class="close-error text-red-400 hover:text-red-300 px-2 py-1 text-xs rounded" title="Close">
            ×
          </button>
        </div>
      </div>
    `;
  }

  attachErrorItemListeners() {
    // Copy error buttons
    document.querySelectorAll('.copy-error').forEach(button => {
      button.addEventListener('click', (e) => {
        const errorId = ((e.target as HTMLElement).closest('.error-item') as HTMLElement)?.dataset.errorId;
        if (errorId) this.copyErrorToClipboard(errorId);
      });
    });

    // Toggle details buttons
    document.querySelectorAll('.toggle-details').forEach(button => {
      button.addEventListener('click', (e) => {
        const errorItem = (e.target as HTMLElement).closest('.error-item');
        const details = errorItem?.querySelector('.technical-details') as HTMLElement;
        const isVisible = details?.style.display !== 'none';

        if (details) details.style.display = isVisible ? 'none' : 'block';
        (e.target as HTMLElement).textContent = isVisible ? 'Details' : 'Hide';
      });
    });

    // Close error buttons
    document.querySelectorAll('.close-error').forEach(button => {
      button.addEventListener('click', (e) => {
        const errorId = ((e.target as HTMLElement).closest('.error-item') as HTMLElement)?.dataset.errorId;
        if (errorId) this.removeError(errorId);
      });
    });
  }

  getErrorIcon(type: string): string {
    return ERROR_TYPE_CONFIGS[type]?.icon || '❌';
  }

  // Unified error detail formatting
  private formatErrorDetails(error: StoredError, format: 'html' | 'text'): string[] {
    const config = ERROR_TYPE_CONFIGS[error.type];
    if (!config) {
      // Fallback for unknown error types
      return this.formatGenericErrorDetails(error, format);
    }

    const details: string[] = [];
    const fields = Object.entries(config.fields);

    // Sort by priority (higher priority first)
    fields.sort(([, a], [, b]) => (b.priority || 0) - (a.priority || 0));

    for (const [fieldPath, fieldConfig] of fields) {
      // Check condition if specified
      if (fieldConfig.condition && !fieldConfig.condition(error)) {
        continue;
      }

      // Get field value using dot notation (e.g., 'error.stack')
      const value = this.getNestedValue(error, fieldPath);
      if (value !== undefined && value !== null && value !== '') {
        const formatter = format === 'html' ? fieldConfig.htmlFormatter : fieldConfig.textFormatter;
        details.push(formatter(value, fieldPath));
      }
    }

    return details;
  }

  // Helper to get nested object values using dot notation
  private getNestedValue(obj: any, path: string): any {
    return path.split('.').reduce((current, key) => current?.[key], obj);
  }

  // Fallback formatter for unknown error types or manual errors
  private formatGenericErrorDetails(error: StoredError, format: 'html' | 'text'): string[] {
    const details: string[] = [];
    const commonFields = ['filename', 'lineno', 'colno', 'stack'];

    // Handle common fields
    for (const field of commonFields) {
      const value = (error as any)[field];
      if (value !== undefined && value !== null && value !== '') {
        if (format === 'html') {
          if (field === 'stack') {
            const preClass = 'text-xs bg-gray-800 p-3 rounded overflow-x-auto whitespace-pre-wrap leading-relaxed';
            details.push(`<div class="mb-3"><div class="mb-1"><strong>${this.capitalize(field)}:</strong></div><pre class="${preClass}">${value}</pre></div>`);
          } else {
            details.push(`<div class="mb-1"><strong>${this.capitalize(field)}:</strong> ${value}</div>`);
          }
        } else {
          details.push(`${this.capitalize(field)}: ${value}`);
        }
      }
    }

    // Handle any additional properties for manual errors
    if (error.type === 'manual') {
      for (const [key, value] of Object.entries(error)) {
        const excludedFields = ['id', 'message', 'type', 'timestamp', ...commonFields];
        if (!excludedFields.includes(key) && value !== undefined && value !== null && value !== '') {
          if (format === 'html') {
            const formattedValue = typeof value === 'object' ? JSON.stringify(value, null, 2) : String(value);
            if (typeof value === 'object') {
              const preClass = 'text-xs bg-gray-800 p-3 rounded overflow-x-auto whitespace-pre-wrap leading-relaxed';
              details.push(`<div class="mb-3"><div class="mb-1"><strong>${this.capitalize(key)}:</strong></div><pre class="${preClass}">${formattedValue}</pre></div>`);
            } else {
              details.push(`<div class="mb-1"><strong>${this.capitalize(key)}:</strong> ${formattedValue}</div>`);
            }
          } else {
            const formattedValue = typeof value === 'object' ? JSON.stringify(value, null, 2) : String(value);
            details.push(`${this.capitalize(key)}: ${formattedValue}`);
          }
        }
      }
    }

    return details;
  }

  // Helper to capitalize first letter
  private capitalize(str: string): string {
    return str.charAt(0).toUpperCase() + str.slice(1);
  }

  formatTechnicalDetails(error: StoredError): string {
    const details = [`<div class='mb-1'><strong>Page URL:</strong> ${window.location.href}</div>`];

    // Use the unified formatting system
    const typeSpecificDetails = this.formatErrorDetails(error, 'html');
    details.push(...typeSpecificDetails);

    return details.join('');
  }

  copyErrorToClipboard(errorId: string): void {
    const error = this.errors.find(e => e.id === errorId);
    if (!error) return;

    const errorReport = this.generateErrorReport(error);
    const button = document.querySelector(`[data-error-id="${errorId}"] .copy-error`) as HTMLElement;

    if (!window.copyToClipboard) {
      this.originalConsoleError('window.copyToClipboard not found');
      alert(`Copy failed. Error details:\n${  errorReport}`);
      return;
    }

    window.copyToClipboard(errorReport).then(() => {
      if (!button) return;
      // Show success feedback
      const originalText = button.textContent;
      button.textContent = 'Copied';
      button.className = button.className.replace('text-blue-400', 'text-green-400');

      setTimeout(() => {
        button.textContent = originalText;
        button.className = button.className.replace('text-green-400', 'text-blue-400');
      }, 2000);
    }).catch(err => {
      this.originalConsoleError('Failed to copy error:', err);
      // Fallback: show error details in a modal or alert
      alert(`Copy failed. Error details:\n${  errorReport}`);
    });
  }

  copyAllErrorsToClipboard(): void {
    if (this.errors.length === 0) return;

    const allErrorsReport = this.generateAllErrorsReport();
    const button = document.getElementById('copy-all-errors') as HTMLElement;

    if (!window.copyToClipboard) {
      this.originalConsoleError('window.copyToClipboard not found');
      alert(`Copy failed. Error details:\n${allErrorsReport}`);
      return;
    }

    window.copyToClipboard(allErrorsReport).then(() => {
      if (!button) return;
      // Show success feedback
      const originalText = button.textContent;
      button.textContent = 'Copied';
      button.className = button.className.replace('text-yellow-400', 'text-green-400');

      setTimeout(() => {
        button.textContent = originalText;
        button.className = button.className.replace('text-green-400', 'text-yellow-400');
      }, 2000);
    }).catch(err => {
      this.originalConsoleError('Failed to copy all errors:', err);
      // Fallback: show error details in a modal or alert
      alert(`Copy failed. Error details:\n${  allErrorsReport}`);
    });
  }

  generateAllErrorsReport(): string {
    const maxErrors = 3; // Show only latest 3 errors
    const maxResponseBodyLength = 400; // Limit response body length
    const maxTotalLength = 2000; // Total character limit

    const recentErrors = this.errors.slice(0, maxErrors);
    const totalErrors = this.errors.reduce((sum, error) => sum + error.count, 0);

    let report = `Frontend Error Report - Recent Errors
════════════════════════════════════
Time: ${new Date().toLocaleString()}
Page URL: ${window.location.href}
Total Errors: ${totalErrors} (showing latest ${recentErrors.length})

`;

    for (let index = 0; index < recentErrors.length; index++) {
      const error = recentErrors[index];
      const countText = error.count > 1 ? ` (${error.count}x)` : '';
      report += `Error ${index + 1}${countText}:
─────────────
${error.message}

Technical Details:`;

      // Use the unified formatting system for text output
      const typeSpecificDetails = this.formatErrorDetails(error, 'text');
      if (typeSpecificDetails.length > 0) {
        // Truncate long details to respect length limits
        const truncatedDetails = typeSpecificDetails.map(detail =>
          this.truncateText(detail, maxResponseBodyLength)
        );
        report += `\n${  truncatedDetails.join('\n')}`;
      }

      // Add timestamp
      report += `\nFirst occurred: ${new Date(error.timestamp).toLocaleString()}`;
      if (error.lastOccurred && error.lastOccurred !== error.timestamp) {
        report += `\nLast occurred: ${new Date(error.lastOccurred).toLocaleString()}`;
      }

      report += '\n\n';

      // Check if exceeding total character limit
      if (report.length > maxTotalLength - 100) { // Reserve 100 chars for ending
        report += `[Report truncated due to length limit]`;
        break;
      }
    }

    // Ensure total length doesn't exceed limit
    if (report.length > maxTotalLength - 50) {
      report = `${report.substring(0, maxTotalLength - 50)  }...\n\n`;
    }

    report += 'Please help me analyze and fix these issues.';
    return report;
  }

  generateErrorReport(error: StoredError): string {
    let report = `Frontend Error Report
─────────────
Time: ${new Date(error.timestamp).toLocaleString()}
Page URL: ${window.location.href}

Technical Details:
${error.message}`;

    // Use the unified formatting system for text output
    const typeSpecificDetails = this.formatErrorDetails(error, 'text');
    if (typeSpecificDetails.length > 0) {
      report += `\n\n${  typeSpecificDetails.join('\n')}`;
    }

    report += `\n\nPlease help me analyze and fix this issue.`;
    return report;
  }

  removeError(errorId: string): void {
    const errorIndex = this.errors.findIndex(e => e.id === errorId);
    if (errorIndex === -1) return;

    const error = this.errors[errorIndex];
    if (error.type in this.errorCounts) {
      this.errorCounts[error.type as keyof ErrorCounts] = Math.max(0, (this.errorCounts[error.type as keyof ErrorCounts] || 0) - error.count);
    }
    this.errors.splice(errorIndex, 1);

    this.updateStatusBar();
    this.updateErrorList();

    // Hide status bar if no errors
    if (this.errors.length === 0) {
      this.hideStatusBar();
    }
  }

  clearAllErrors() {
    this.errors = [];
    this.errorCounts = {
      javascript: 0,
      interaction: 0,
      network: 0,
      promise: 0,
      http: 0,
      actioncable: 0,
      asyncjob: 0,
      manual: 0,
      stimulus: 0
    };

    this.updateStatusBar();
    this.updateErrorList();
    this.hideStatusBar();
  }

  showStatusBar(): void {
    if (this.statusBar) {
      this.statusBar.style.display = 'block';
      console.log('Status bar shown');
    } else {
      console.log('Cannot show status bar - not created yet');
    }
  }

  hideStatusBar(): void {
    if (this.statusBar) {
      this.statusBar.style.display = 'none';
      this.isExpanded = false;
      const errorDetails = document.getElementById('error-details');
      const toggleText = document.getElementById('toggle-text');
      const toggleIcon = document.getElementById('toggle-icon');

      if (errorDetails) errorDetails.style.display = 'none';
      if (toggleText) toggleText.textContent = 'Show';
      if (toggleIcon) toggleIcon.textContent = '↑';
    }
  }

  flashNewError(): void {
    // Flash the status bar to indicate new error
    if (this.statusBar) {
      this.statusBar.style.borderTopColor = '#ef4444';
      this.statusBar.style.borderTopWidth = '2px';

      setTimeout(() => {
        if (this.statusBar) {
          this.statusBar.style.borderTopColor = '#374151';
          this.statusBar.style.borderTopWidth = '1px';
        }
      }, 1000);
    }
  }

  checkAutoExpand(errorInfo: ErrorInfo): void {
    // Auto-expand logic disabled
    // Auto-expand if this is the first error ever
    // if (!this.hasShownFirstError) {
    //   this.hasShownFirstError = true;
    //   this.autoExpandErrorDetails();
    //   return;
    // }

    // Auto-expand if this is an interaction error (user just performed an action)
    // if (errorInfo.type === 'interaction' ||
    //     (this.lastInteractionTime && Date.now() - this.lastInteractionTime < 3000)) {
    //   this.autoExpandErrorDetails();
    //   return;
    // }
  }

  autoExpandErrorDetails() {
    // Auto-expand logic disabled
    // if (!this.isExpanded) {
    //   setTimeout(() => {
    //     const toggleButton = document.getElementById('toggle-errors');
    //     if (toggleButton) {
    //       toggleButton.click();
    //     }
    //   }, 100); // Small delay to ensure UI is ready
    // }
  }

  sanitizeMessage(message: string): string {
    if (!message) return 'Unknown error';

    const cleanMessage = message
      .replace(/<[^>]*>/g, '') // Remove HTML tags
      .replace(/\n/g, ' ') // Replace newlines with spaces
      .trim();

    return cleanMessage.length > 100
      ? `${cleanMessage.substring(0, 100)  }...`
      : cleanMessage;
  }

  truncateText(text: string, maxLength: number): string {
    if (!text) return '';
    if (text.length <= maxLength) return text;
    return `${text.substring(0, maxLength)  }... [truncated]`;
  }

  extractFilename(filepath: string): string {
    if (!filepath) return '';
    return filepath.split('/').pop() || filepath;
  }

  cleanupDebounceMap() {
    // Clean up debounce entries older than debounceTime * 10
    const cutoffTime = Date.now() - (this.debounceTime * 10);
    for (const [key, timestamp] of this.recentErrorsDebounce.entries()) {
      if (timestamp < cutoffTime) {
        this.recentErrorsDebounce.delete(key);
      }
    }
  }

  // Public API methods
  getErrors(): StoredError[] {
    return this.errors;
  }

  reportError(message: string, context: Partial<ErrorInfo> = {}): void {
    this.handleError({
      message: message,
      type: 'manual',
      timestamp: new Date().toISOString(),
      ...context
    });
  }

  // ActionCable specific error capturing
  captureActionCableError(errorData: any): void {
    this.errorCounts.actioncable++;

    const errorInfo: ActionCableErrorInfo = {
      type: 'actioncable',
      message: errorData.message || 'ActionCable error occurred',
      timestamp: new Date().toISOString(),
      channel: errorData.channel || 'unknown',
      action: errorData.action || 'unknown',
      filename: `channel: ${errorData.channel}`,
      lineno: 0,
      details: errorData
    };

    this.handleError(errorInfo);
  }

  // Source Map related methods
  private async getSourceMapConsumer(fileUrl: string): Promise<SourceMapConsumer | null> {
    // Check cache first
    if (this.sourceMapCache.has(fileUrl)) {
      return this.sourceMapCache.get(fileUrl)!;
    }

    // Check if already pending
    if (this.sourceMapPending.has(fileUrl)) {
      return this.sourceMapPending.get(fileUrl)!;
    }

    // Create new promise
    const promise = this.loadSourceMap(fileUrl);
    this.sourceMapPending.set(fileUrl, promise);

    const consumer = await promise;
    this.sourceMapPending.delete(fileUrl);

    if (consumer) {
      this.sourceMapCache.set(fileUrl, consumer);
    }

    return consumer;
  }

  private async loadSourceMap(fileUrl: string): Promise<SourceMapConsumer | null> {
    try {
      const response = await fetch(fileUrl);
      const sourceCode = await response.text();

      // Extract inline source map (base64 encoded)
      const sourceMapMatch = sourceCode.match(/\/\/# sourceMappingURL=data:application\/json;base64,([^\s]+)/);
      if (!sourceMapMatch) {
        return null;
      }

      const base64SourceMap = sourceMapMatch[1];
      const sourceMapJson = atob(base64SourceMap);
      const sourceMap = JSON.parse(sourceMapJson);

      return await new SourceMapConsumer(sourceMap);
    } catch (error) {
      this.originalConsoleError('Failed to load source map for', fileUrl, error);
      return null;
    }
  }

  private normalizeSourcePath(sourcePath: string): string {
    if (!sourcePath) return sourcePath;

    // Remove leading "../" or "./" patterns
    let normalized = sourcePath.replace(/^(?:\.\.\/)+/, '').replace(/^\.\//, '');

    // Prepend "app/" if it starts with "javascript/"
    if (normalized.startsWith('javascript/')) {
      normalized = `app/${normalized}`;
    }

    return normalized;
  }

  async mapStackTrace(stack: string): Promise<string> {
    if (!stack) return stack;

    const lines = stack.split('\n');
    const mappedLines = await Promise.all(lines.map(async (line) => {
      // Parse stack trace line - handle multiple formats
      // Format 1: "at functionName (http://localhost:3000/assets/application.js:123:45)"
      // Format 2: "at http://localhost:3000/assets/application.js:123:45"
      const match = line.match(/^\s*at\s+(?:(.+?)\s+\()?(.+?):(\d+):(\d+)\)?$/);
      if (!match) return line;

      const [, functionName, fileUrl, lineStr, columnStr] = match;
      const line_num = parseInt(lineStr, 10);
      const column = parseInt(columnStr, 10);

      // Skip if fileUrl doesn't look like a valid URL
      if (!fileUrl || (!fileUrl.startsWith('http://') && !fileUrl.startsWith('https://'))) {
        return line;
      }

      const consumer = await this.getSourceMapConsumer(fileUrl);
      if (!consumer) return line;

      const originalPosition = consumer.originalPositionFor({
        line: line_num,
        column: column
      });

      if (originalPosition.source) {
        const normalizedSource = this.normalizeSourcePath(originalPosition.source);
        const prefix = functionName ? `at ${functionName} (` : 'at ';
        const suffix = functionName ? ')' : '';
        return `${prefix}${normalizedSource}:${originalPosition.line}:${originalPosition.column}${suffix}`;
      }

      return line;
    }));

    return mappedLines.join('\n');
  }

  async enrichErrorWithSourceMap(errorInfo: ErrorInfo): Promise<ErrorInfo> {
    let enriched = { ...errorInfo };

    // Map filename and line number if available
    if (errorInfo.filename && errorInfo.lineno && errorInfo.colno) {
      try {
        const consumer = await this.getSourceMapConsumer(errorInfo.filename);
        if (consumer) {
          const originalPosition = consumer.originalPositionFor({
            line: errorInfo.lineno,
            column: errorInfo.colno
          });

          if (originalPosition.source) {
            enriched = {
              ...enriched,
              filename: this.normalizeSourcePath(originalPosition.source),
              lineno: originalPosition.line || errorInfo.lineno,
              colno: originalPosition.column !== null ? originalPosition.column : errorInfo.colno
            };
          }
        }
      } catch (error) {
        this.originalConsoleError('Failed to map error position', error);
      }
    }

    // Map stack trace if available
    if (errorInfo.error?.stack) {
      try {
        const mappedStack = await this.mapStackTrace(errorInfo.error.stack);
        enriched = {
          ...enriched,
          error: {
            ...errorInfo.error,
            stack: mappedStack
          }
        };
      } catch (error) {
        this.originalConsoleError('Failed to map stack trace', error);
      }
    }

    return enriched;
  }
}

// Initialize error handler immediately (don't wait for DOM)
window.errorHandler = new ErrorHandler();
