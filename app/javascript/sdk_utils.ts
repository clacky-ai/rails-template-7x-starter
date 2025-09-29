// SDK Utility for chatbox integration
// Handles chatbox SDK detection and message sending

class SDKUtils {
  private isAvailable: boolean;

  constructor() {
    this.isAvailable = this.checkSDKAvailability();
  }

  /**
   * Check if SDK is available in current context
   */
  checkSDKAvailability(): boolean {
    return typeof window.sdk !== 'undefined' && 
           window.sdk && 
           typeof window.sdk.send === 'function';
  }

  /**
   * Send message to chatbox if SDK is available
   * @param {string} message - Message to send
   * @returns {boolean} - Whether message was sent successfully
   */
  sendMessage(message: string): boolean {
    if (this.isAvailable) {
      try {
        window.sdk!.send(message);
        console.log('Message sent to chatbox:', message);
        return true;
      } catch (error) {
        console.error('Failed to send message to SDK:', error);
        return false;
      }
    } else {
      console.log('SDK not available. Would send message:', message);
      return false;
    }
  }

  /**
   * Send error details to chatbox for fixing
   * @param {Object} errorInfo - Error information object
   */
  sendErrorForFix(errorInfo: any = {}): boolean {
    const {
      url = window.location.href,
      path = window.location.pathname.substring(1),
      errorMessage = 'Unknown error',
      additionalContext = ''
    } = errorInfo;

    const message = `Fix this error:
URL: ${url}
Error: ${errorMessage}
Path: ${path}${additionalContext ? `\n\nAdditional Context:\n${  additionalContext}` : ''}

Please help me fix this issue.`;

    return this.sendMessage(message);
  }

  /**
   * Refresh SDK availability status
   */
  refresh(): boolean {
    this.isAvailable = this.checkSDKAvailability();
    return this.isAvailable;
  }

  /**
   * Get current SDK status
   */
  getStatus(): { isAvailable: boolean; hasSDK: boolean; hasSendMethod: boolean } {
    return {
      isAvailable: this.isAvailable,
      hasSDK: typeof window.sdk !== 'undefined',
      hasSendMethod: typeof window.sdk?.send === 'function'
    };
  }
}

// Create singleton instance
const sdkUtils = new SDKUtils();

// Global function for backward compatibility
window.sendToSDK = (message) => sdkUtils.sendMessage(message);
window.sendErrorToSDK = (errorInfo) => sdkUtils.sendErrorForFix(errorInfo);
window.isSDKAvailable = () => sdkUtils.getStatus().isAvailable;

// Export globally
window.sdkUtils = sdkUtils;

export default sdkUtils;
