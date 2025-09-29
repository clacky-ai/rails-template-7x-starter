# config/initializers/smart_permit_patch.rb
module SmartRequirePatch
  def require(key)
    super(key)
  rescue ActionController::ParameterMissing
    if self.has_key?(key)
      raise
    else
      self
    end
  end
end

module SmartPermitPatch
  def permit(*filters)
    smart_filters = filters.map do |filter|
      case filter
      when Symbol, String
        field_name = filter.to_s
        if self[field_name].is_a?(Array)
          { field_name.to_sym => [] }
        else
          filter
        end
      when Hash
        # change xxx => {} to :xxx
        if filter.values.first == {}
          filter.keys.first
        else
          filter
        end
      else
        filter
      end
    end

    super(*smart_filters)
  end
end

ActionController::Parameters.prepend(SmartRequirePatch)
ActionController::Parameters.prepend(SmartPermitPatch)
