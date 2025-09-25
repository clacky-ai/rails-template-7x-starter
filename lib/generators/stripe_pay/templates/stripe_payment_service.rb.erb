class StripePaymentService < ApplicationService
  include Rails.application.routes.url_helpers
  attr_reader :order, :payment_intent, :checkout_session

  def initialize(order, request = nil)
    @order = order
    @request = request
  end

  def call
    create_checkout_session
  end

  # Create Checkout Session for Stripe
  def create_checkout_session
    # Check if order is in valid state for payment
    unless order.pending? || order.failed?
      return { success: false, error: "Order is not in a valid state for payment (current status: #{order.status})" }
    end

    begin
      @checkout_session = Stripe::Checkout::Session.create(
        payment_method_types: ['card'],
        line_items: [
          {
            price_data: {
              currency: order.currency,
              product_data: {
                name: order.product_name,
                description: "Order for #{order.customer_name}",
              },
              unit_amount: order.amount_in_cents,
            },
            quantity: 1,
          }
        ],
        mode: 'payment',
        customer_email: order.customer_email,
        success_url: success_order_url(order, only_path: false),
        cancel_url: failure_order_url(order, only_path: false),
        metadata: {
          order_id: order.id,
          customer_email: order.customer_email,
          customer_name: order.customer_name,
          product_name: order.product_name
        }
      )

      # Update order with checkout session ID
      order.update!(
        stripe_payment_intent_id: @checkout_session.id,
        status: 'processing'
      )

      { success: true, checkout_session: @checkout_session }
    rescue Stripe::StripeError => e
      order.mark_as_failed!
      { success: false, error: e.message }
    end
  end

  # Legacy method for backward compatibility
  def create_payment_intent
    create_checkout_session
  end

  # Confirm payment intent
  def self.confirm_payment(payment_intent_id, payment_method_id)
    begin
      payment_intent = Stripe::PaymentIntent.confirm(
        payment_intent_id,
        payment_method: payment_method_id
      )
      { success: true, payment_intent: payment_intent }
    rescue Stripe::StripeError => e
      { success: false, error: e.message }
    end
  end

  # Retrieve payment intent
  def self.retrieve_payment_intent(payment_intent_id)
    begin
      Stripe::PaymentIntent.retrieve(payment_intent_id)
    rescue Stripe::StripeError => e
      Rails.logger.error "Failed to retrieve payment intent: #{e.message}"
      nil
    end
  end

  # Process webhook events
  def self.process_webhook_event(event)
    case event['type']
    when 'checkout.session.completed'
      handle_checkout_success(event['data']['object'])
    when 'checkout.session.expired'
      handle_checkout_expiration(event['data']['object'])
    when 'payment_intent.succeeded'
      handle_payment_success(event['data']['object'])
    when 'payment_intent.payment_failed'
      handle_payment_failure(event['data']['object'])
    when 'payment_intent.canceled'
      handle_payment_cancellation(event['data']['object'])
    else
      Rails.logger.info "Unhandled event type: #{event['type']}"
    end
  end

  private

  def self.handle_checkout_success(checkout_session)
    order = Order.find_by(stripe_payment_intent_id: checkout_session['id'])
    return unless order

    order.mark_as_paid!
    Rails.logger.info "Checkout session completed for order #{order.id}"

    # Here you can add additional logic like:
    # - Send confirmation email
    # - Update inventory
    # - Trigger fulfillment process
  end

  def self.handle_checkout_expiration(checkout_session)
    order = Order.find_by(stripe_payment_intent_id: checkout_session['id'])
    return unless order

    order.mark_as_canceled!
    Rails.logger.info "Checkout session expired for order #{order.id}"
  end

  def self.handle_payment_success(payment_intent)
    order = Order.find_by(stripe_payment_intent_id: payment_intent['id'])
    return unless order

    order.mark_as_paid!
    Rails.logger.info "Payment succeeded for order #{order.id}"

    # Here you can add additional logic like:
    # - Send confirmation email
    # - Update inventory
    # - Trigger fulfillment process
  end

  def self.handle_payment_failure(payment_intent)
    order = Order.find_by(stripe_payment_intent_id: payment_intent['id'])
    return unless order

    order.mark_as_failed!
    Rails.logger.info "Payment failed for order #{order.id}"
  end

  def self.handle_payment_cancellation(payment_intent)
    order = Order.find_by(stripe_payment_intent_id: payment_intent['id'])
    return unless order

    order.mark_as_canceled!
    Rails.logger.info "Payment canceled for order #{order.id}"
  end
end
