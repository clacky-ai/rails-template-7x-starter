# app/services/application_service.rb
class ApplicationService
  Result = Struct.new(:success, :data, :error, keyword_init: true) do
    def success?
      success
    end
  end

  def self.call(*args, **kwargs, &block)
    new(*args, **kwargs).call(&block)
  end

  private

  def success(data = {})
    Result.new(success: true, data: data, error: nil)
  end

  def failure(error)
    Result.new(success: false, data: {}, error: error)
  end
end
