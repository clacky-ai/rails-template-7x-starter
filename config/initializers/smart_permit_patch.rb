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

    result = super(*smart_filters)

    # Post-process: Handle hash-style nested attributes with any prefix (e.g., "new_0", "abc_1", "0")
    filters.each do |filter|
      next unless filter.is_a?(Hash)

      filter.each do |key, permitted_attrs|
        hash_param = self[key]
        next unless permitted_attrs.is_a?(Array) && hash_param.respond_to?(:each)

        # Permit each hash entry individually, supporting any key format
        permitted_hash = {}
        hash_param.each do |hash_key, hash_val|
          if hash_val.is_a?(ActionController::Parameters)
            permitted_hash[hash_key] = hash_val.permit(*permitted_attrs)
          end
        end

        result[key] = ActionController::Parameters.new(permitted_hash).permit! unless permitted_hash.empty?
      end
    end

    result
  end
end

ActionController::Parameters.prepend(SmartRequirePatch)
ActionController::Parameters.prepend(SmartPermitPatch)
