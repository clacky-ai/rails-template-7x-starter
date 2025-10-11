# app/services/application_service.rb
class ApplicationService
  def self.call(*args, **kwargs, &block)
    new(*args, **kwargs).call(&block)
  end
end
