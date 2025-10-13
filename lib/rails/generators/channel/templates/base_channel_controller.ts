import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

/**
 * BaseChannelController - Base class for all ActionCable channel controllers
 * Provides error reporting, WebSocket management, and button state restoration
 *
 * CRITICAL: Do not modify reportError - these prevent
 * errors from being lost and UI from getting stuck
 *
 * Usage:
 *   import BaseChannelController from "./base_channel_controller"
 *
 *   export default class extends BaseChannelController {
 *     connect() {
 *       this.createSubscription("YourChannel", { session_id: "123" })
 *     }
 *
 *     protected channelReceived(data: any) {
 *       // Handle your messages
 *     }
 *   }
 */
export class BaseChannelController extends Controller<HTMLElement> {
  protected subscription: any = null
  protected isConnected: boolean = false

  /**
   * Report error to global error handler
   * CRITICAL: Do not remove - prevents error loss
   */
  protected reportError(errorData: any): void {
    if (window.errorHandler?.captureActionCableError) {
      window.errorHandler.captureActionCableError({
        ...errorData,
        controllerName: this.identifier
      })
    } else {
      console.error(`[${this.identifier}] Error:`, errorData)
    }
  }

  /**
   * Restore button states after operations
   * CRITICAL: Do not remove - prevents stuck UI states
   */
  protected restoreButtonStates(): void {
    if (typeof window.restoreButtonStates === 'function') {
      window.restoreButtonStates()
    }
  }

  /**
   * Create ActionCable subscription
   * Override channelConnected/channelDisconnected/channelReceived to handle events
   */
  protected createSubscription(channelName: string, params: Record<string, any> = {}): void {
    if (this.subscription) return

    this.subscription = consumer.subscriptions.create(
      { channel: channelName, ...params },
      {
        connected: this.handleChannelConnected.bind(this),
        disconnected: this.handleChannelDisconnected.bind(this),
        received: this.handleChannelReceived.bind(this)
      }
    )
  }

  /**
   * Destroy ActionCable subscription
   */
  protected destroySubscription(): void {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
      this.isConnected = false
    }
  }

  /**
   * Internal: Handle connection - restores button states
   */
  private handleChannelConnected(): void {
    console.log(`[${this.identifier}] Connected to channel`)
    this.isConnected = true
    this.restoreButtonStates()
    this.channelConnected()
  }

  /**
   * Internal: Handle disconnection - reports error
   */
  private handleChannelDisconnected(): void {
    console.log(`[${this.identifier}] Disconnected from channel`)
    this.isConnected = false
  }

  /**
   * Internal: Handle received data - restores button states and handles errors
   */
  private handleChannelReceived(data: any): void {
    this.restoreButtonStates()

    // report Global error handling
    if (data.type === 'system-error') {
      this.reportError(data)
      return
    }

    this.channelReceived(data)
  }

  /**
   * Override: Called when channel connects
   */
  protected channelConnected(): void {
    // Override in subclass
  }

  /**
   * Override: Called when channel disconnects
   */
  protected channelDisconnected(): void {
    // Override in subclass
  }

  /**
   * Override: Called when data received from channel
   */
  protected channelReceived(data: any): void {
    // Override in subclass
  }

  /**
   * Get WebSocket connection status
   */
  get connected(): boolean {
    return this.isConnected
  }
}

export default BaseChannelController
