// Enhanced JavaScript Error Handler with Persistent Status Bar
// Provides user-friendly error monitoring with permanent visibility

class ErrorHandler {
  constructor() {
    this.errors = [];
    this.maxErrors = 50;
    this.isExpanded = false;
    this.statusBar = null;
    this.errorList = null;
    this.isInteractionError = false;
    this.errorCounts = {
      javascript: 0,
      interaction: 0,
      network: 0,
      promise: 0,
      http: 0,
      actioncable: 0
    };
    this.recentErrorsDebounce = new Map(); // For debouncing similar errors
    this.debounceTime = 1000; // 1 second debounce
    this.uiReady = false; // Track if UI is ready
    this.pendingUIUpdates = false; // Track if we need to update UI when ready
    this.hasShownFirstError = false; // Track if we've shown first error
    this.lastInteractionTime = 0; // Track last user interaction
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
      
      // Check if we need to auto-expand for first error
      if (!this.hasShownFirstError && this.errors.length > 0) {
        this.hasShownFirstError = true;
        this.autoExpandErrorDetails();
      }
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
        </div>
        <div class="flex items-center space-x-2">
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
        <div class="px-4 py-2 border-b border-gray-600 bg-gray-750">
          <p class="text-xs text-gray-300">
            💡 Send to chatbox for repair (90% cases) or ignore if browser extension (10% cases)
          </p>
        </div>
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
    document.getElementById('toggle-errors').addEventListener('click', () => {
      this.toggleErrorDetails();
    });

    // Clear all errors
    document.getElementById('clear-all-errors').addEventListener('click', () => {
      this.clearAllErrors();
    });
  }

  toggleErrorDetails() {
    const details = document.getElementById('error-details');
    const toggleText = document.getElementById('toggle-text');
    const toggleIcon = document.getElementById('toggle-icon');

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
    // Capture uncaught JavaScript errors
    window.addEventListener('error', (event) => {
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
            url: args[0],
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
          message: `${method} ${args[0]} - Network Error: ${error.message}`,
          url: args[0],
          method: method,
          error: error,
          type: 'network',
          timestamp: new Date().toISOString()
        });
        throw error;
      }
    };
  }

  handleError(errorInfo) {
    console.log('handleError called with:', errorInfo.message, errorInfo.type);
    // Filter out browser-specific errors we can't control
    if (this.shouldIgnoreError(errorInfo)) {
      console.log('Error ignored due to filter');
      return;
    }

    // Create a debounce key for similar errors
    const debounceKey = `${errorInfo.type}_${errorInfo.message}_${errorInfo.filename}_${errorInfo.lineno}`;

    // Check if this error was recently processed (debouncing)
    if (this.recentErrorsDebounce.has(debounceKey)) {
      const lastTime = this.recentErrorsDebounce.get(debounceKey);
      if (Date.now() - lastTime < this.debounceTime) {
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
    this.errorCounts[errorInfo.type]++;

    // Update UI (if ready) or mark for later update
    if (this.uiReady) {
      this.updateStatusBar();
      this.updateErrorList();
      this.showStatusBar();
      this.flashNewError();
      
      // Auto-expand for first error or interaction errors
      this.checkAutoExpand(errorInfo);
    } else {
      console.log('UI not ready, marking for later update');
      this.pendingUIUpdates = true;
    }

    // Clean up old debounce entries
    this.cleanupDebounceMap();

    // Log to console for debugging
    console.error('Captured Error:', errorInfo);
  }

  shouldIgnoreError(errorInfo) {
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

  findDuplicateError(errorInfo) {
    return this.errors.find(error =>
      error.message === errorInfo.message &&
      error.type === errorInfo.type &&
      error.filename === errorInfo.filename &&
      error.lineno === errorInfo.lineno
    );
  }

  generateErrorId() {
    return 'error_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  }

  updateStatusBar() {
    const summary = document.getElementById('error-summary');
    if (!summary) return; // UI not ready yet

    const totalErrors = this.errors.reduce((sum, error) => sum + error.count, 0);

    if (totalErrors === 0) {
      summary.innerHTML = '<span class="text-green-400">✓ No Errors</span>';
      return;
    }

    // Unified error display without type distinction
    summary.innerHTML = `<span class="text-red-400">🔴 Frontend code error detected (${totalErrors})</span>`;
  }

  updateErrorList() {
    if (!this.errorList) return; // UI not ready yet

    const listHTML = this.errors.map(error => this.createErrorItemHTML(error)).join('');
    this.errorList.innerHTML = listHTML;

    // Attach event listeners to new error items
    this.attachErrorItemListeners();
  }

  createErrorItemHTML(error) {
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
        const errorId = e.target.closest('.error-item').dataset.errorId;
        this.copyErrorToClipboard(errorId);
      });
    });

    // Toggle details buttons
    document.querySelectorAll('.toggle-details').forEach(button => {
      button.addEventListener('click', (e) => {
        const errorItem = e.target.closest('.error-item');
        const details = errorItem.querySelector('.technical-details');
        const isVisible = details.style.display !== 'none';

        details.style.display = isVisible ? 'none' : 'block';
        e.target.textContent = isVisible ? 'Details' : 'Hide';
      });
    });

    // Close error buttons
    document.querySelectorAll('.close-error').forEach(button => {
      button.addEventListener('click', (e) => {
        const errorId = e.target.closest('.error-item').dataset.errorId;
        this.removeError(errorId);
      });
    });
  }

  getErrorIcon(type) {
    switch (type) {
      case 'interaction': return '🔴';
      case 'javascript': return '⚠️';
      case 'network': return '📡';
      case 'http': return '🌐';
      case 'promise': return '⚡';
      default: return '❌';
    }
  }

  formatTechnicalDetails(error) {
    const details = [];

    details.push(`<div><strong>Page URL:</strong> ${window.location.href}</div>`);

    // For fetch/network errors, show detailed HTTP information
    if (error.type === 'http' || error.type === 'network') {
      if (error.method) {
        details.push(`<div><strong>Method:</strong> ${error.method}</div>`);
      }
      if (error.status) {
        details.push(`<div><strong>Status Code:</strong> ${error.status}</div>`);
      }
      
      // Show JSON error details if available
      if (error.jsonError) {
        details.push(`<div class="mb-1"><strong>JSON Error Details:</strong></div>`);
        details.push(`<pre class="text-xs bg-gray-800 p-2 rounded overflow-x-auto whitespace-pre-wrap">${JSON.stringify(error.jsonError, null, 2)}</pre>`);
      }
      
      // Show response body if available and different from JSON error
      if (error.responseBody && (!error.jsonError || error.responseBody !== JSON.stringify(error.jsonError, null, 2))) {
        details.push(`<div class="mb-1"><strong>Response Body:</strong></div>`);
        details.push(`<pre class="text-xs bg-gray-800 p-2 rounded overflow-x-auto whitespace-pre-wrap">${error.responseBody}</pre>`);
      }
    }

    if (error.lineno) {
      details.push(`<div><strong>Line:</strong> ${error.lineno}</div>`);
    }

    if (error.error && error.error.stack) {
      details.push(`<div class="mb-1"><strong>Stack Trace:</strong></div>`);
      details.push(`<pre class="text-xs bg-gray-800 p-2 rounded overflow-x-auto whitespace-pre-wrap">${error.error.stack}</pre>`);
    }

    return details.join('');
  }

  copyErrorToClipboard(errorId) {
    const error = this.errors.find(e => e.id === errorId);
    if (!error) return;

    const errorReport = this.generateErrorReport(error);

    navigator.clipboard.writeText(errorReport).then(() => {
      // Show success feedback
      const button = document.querySelector(`[data-error-id="${errorId}"] .copy-error`);
      const originalText = button.textContent;
      button.textContent = 'Copied';
      button.className = button.className.replace('text-blue-400', 'text-green-400');

      setTimeout(() => {
        button.textContent = originalText;
        button.className = button.className.replace('text-green-400', 'text-blue-400');
      }, 2000);
    }).catch(err => {
      console.error('Failed to copy error:', err);
      // Fallback: show error details in a modal or alert
      alert('Copy failed. Error details:\n' + errorReport);
    });
  }

  generateErrorReport(error) {
    let report = `Frontend Error Report
─────────────
Time: ${new Date(error.timestamp).toLocaleString()}
Page URL: ${window.location.href}

Technical Details:
${error.message}`;

    // Add HTTP-specific details for fetch/network errors
    if (error.type === 'http' || error.type === 'network') {
      if (error.method) {
        report += `\nMethod: ${error.method}`;
      }
      if (error.status) {
        report += `\nStatus Code: ${error.status}`;
      }
      if (error.jsonError) {
        report += `\nJSON Error Details:\n${JSON.stringify(error.jsonError, null, 2)}`;
      }
      if (error.responseBody && (!error.jsonError || error.responseBody !== JSON.stringify(error.jsonError, null, 2))) {
        report += `\nResponse Body:\n${error.responseBody}`;
      }
    }

    // Add file and line info for JavaScript errors
    if (error.filename) {
      report += `\nFile: ${error.filename}`;
    }
    if (error.lineno) {
      report += `\nLine: ${error.lineno}`;
    }

    // Add stack trace if available
    if (error.error && error.error.stack) {
      report += `\n\nStack Trace:\n${error.error.stack}`;
    }

    report += `\n\nPlease help me analyze and fix this issue.`;
    return report;
  }

  removeError(errorId) {
    const errorIndex = this.errors.findIndex(e => e.id === errorId);
    if (errorIndex === -1) return;

    const error = this.errors[errorIndex];
    this.errorCounts[error.type] = Math.max(0, this.errorCounts[error.type] - error.count);
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
      http: 0
    };

    this.updateStatusBar();
    this.updateErrorList();
    this.hideStatusBar();
  }

  showStatusBar() {
    if (this.statusBar) {
      this.statusBar.style.display = 'block';
      console.log('Status bar shown');
    } else {
      console.log('Cannot show status bar - not created yet');
    }
  }

  hideStatusBar() {
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

  flashNewError() {
    // Flash the status bar to indicate new error
    if (this.statusBar) {
      this.statusBar.style.borderTopColor = '#ef4444';
      this.statusBar.style.borderTopWidth = '2px';

      setTimeout(() => {
        this.statusBar.style.borderTopColor = '#374151';
        this.statusBar.style.borderTopWidth = '1px';
      }, 1000);
    }
  }

  checkAutoExpand(errorInfo) {
    // Auto-expand if this is the first error ever
    if (!this.hasShownFirstError) {
      this.hasShownFirstError = true;
      this.autoExpandErrorDetails();
      return;
    }
    
    // Auto-expand if this is an interaction error (user just performed an action)
    if (errorInfo.type === 'interaction' || 
        (this.lastInteractionTime && Date.now() - this.lastInteractionTime < 3000)) {
      this.autoExpandErrorDetails();
      return;
    }
  }
  
  autoExpandErrorDetails() {
    if (!this.isExpanded) {
      setTimeout(() => {
        const toggleButton = document.getElementById('toggle-errors');
        if (toggleButton) {
          toggleButton.click();
        }
      }, 100); // Small delay to ensure UI is ready
    }
  }

  sanitizeMessage(message) {
    if (!message) return 'Unknown error';

    const cleanMessage = message
      .replace(/<[^>]*>/g, '') // Remove HTML tags
      .replace(/\n/g, ' ') // Replace newlines with spaces
      .trim();

    return cleanMessage.length > 100
      ? cleanMessage.substring(0, 100) + '...'
      : cleanMessage;
  }

  extractFilename(filepath) {
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
  getErrors() {
    return this.errors;
  }

  reportError(message, context = {}) {
    this.handleError({
      message: message,
      type: 'manual',
      timestamp: new Date().toISOString(),
      ...context
    });
  }

  // ActionCable specific error handling
  handleActionCableError(errorData) {
    this.errorCounts.actioncable++;
    
    const errorInfo = {
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
}

// Initialize error handler immediately (don't wait for DOM)
window.errorHandler = new ErrorHandler();
