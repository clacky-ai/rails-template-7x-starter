class MailDeliveryJob < ApplicationJob
  queue_as :mailers

  def perform(mailer, mail_method, delivery_method, args:, kwargs: nil, params: nil)
    kwargs ||= {}
    mailer.constantize.with(params).public_send(mail_method, *args, **kwargs).send(delivery_method)
  end
end
