// Global type declarations
import { Application } from "@hotwired/stimulus"

declare global {
  interface Window {
    Stimulus: Application;
    Alpine: any;
    ActionCable: any;
    Turbo: any;
    App: {
      cable: any;
      adminSidebar?: any;
    };
    restoreButtonStates: () => void;
    errorHandler: ErrorHandler;
    stimulusValidator: any;
    copyToClipboard: (text: string) => Promise<boolean>;
    sdkUtils: any;
    sendToSDK: (message: string) => boolean;
    sendErrorToSDK: (errorInfo: any) => boolean;
    isSDKAvailable: () => boolean;
    sdk?: {
      send: (message: string) => void;
    };
  }

  var App: {
    cable: any;
    adminSidebar?: any;
  };
}

// ActionCable types
declare module '@rails/actioncable' {
  export function createConsumer(url?: string): any;
  export * as ActionCable from '@rails/actioncable';
  
  interface Consumer {
    subscriptions: any;
  }
  
  interface Channel {
    perform: (action: string, data?: any) => void;
    send: (data: any) => void;
  }
}

// ActiveStorage types  
declare module '@rails/activestorage' {
  export function start(): void;
}

// AlpineJS types
declare module 'alpinejs' {
  interface Alpine {
    start(): void;
    data(name: string, callback: () => any): void;
  }

  const Alpine: Alpine;
  export default Alpine;
}

export {};
