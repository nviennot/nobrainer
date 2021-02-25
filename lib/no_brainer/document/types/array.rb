require 'active_support/core_ext/array/wrap'

module NoBrainer
  class Array < ::Array
    # delegate cast to each array element
    def self.nobrainer_cast_user_to_model(values)
      ::Array.wrap(values).map do |value|
        if value.class.respond_to?(:nobrainer_cast_user_to_model)
          value.class.nobrainer_cast_user_to_model(value)
        else
          value
        end
      end
    end

    # delegate cast to each array element
    def self.nobrainer_cast_model_to_db(values)
      ::Array.wrap(values).map do |value|
        if value.class.respond_to?(:nobrainer_cast_model_to_db)
          value.class.nobrainer_cast_model_to_db(value)
        else
          value
        end
      end
    end

    # delegate cast to each array element
    def self.nobrainer_cast_db_to_model(values)
      ::Array.wrap(values).map do |value|
        if value.class.respond_to?(:nobrainer_cast_db_to_model)
          value.class.nobrainer_cast_db_to_model(method, value)
        else
          value
        end
      end
    end

    # convenience method to create a TypedArray
    def self.of(object_type = nil, **options)
      NoBrainer::TypedArray.of(object_type, **options)
    end
  end

  class TypedArray < Array
    def self.of(object_type, allow_nil: false)
      NoBrainer::Document::Types.load_type_extensions(object_type)
      ::Class.new(TypedArray) do
        define_singleton_method(:object_type) { object_type }
        define_singleton_method(:allow_nil?) { allow_nil }
      end
    end

    def self.name
      str = String.new "Array"
      str += "(#{object_type.name})"  if respond_to?(:object_type)
      str
    end

    # delegate cast methods to object_type cast methods, if defined
    def self.nobrainer_cast_user_to_model(values)
      cast_type = object_type.respond_to?(:nobrainer_cast_user_to_model) && object_type
      values = ::Array.wrap(values).map do |value|
        value = cast_type.nobrainer_cast_user_to_model(value)  if cast_type
        unless (value.nil? && allow_nil?) || value.is_a?(object_type)
          raise NoBrainer::Error::InvalidType, type: object_type.name, value: value
        end
        value
      end
      new(values)
    end

    def self.nobrainer_cast_model_to_db(values)
      values = ::Array.wrap(values)
      if object_type.respond_to?(:nobrainer_cast_model_to_db)
        values.map { |value| object_type.nobrainer_cast_model_to_db(value) }
      else
        values
      end
    end

    def self.nobrainer_cast_db_to_model(values)
      values = ::Array.wrap(values)
      if object_type.respond_to?(:nobrainer_cast_db_to_model)
        values.map { |value| object_type.nobrainer_cast_db_to_model(value) }
      else
        values
      end
    end
  end
end
