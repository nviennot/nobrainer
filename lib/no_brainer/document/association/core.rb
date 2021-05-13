module NoBrainer::Document::Association::Core
  extend ActiveSupport::Concern

  module Metadata
    extend ActiveSupport::Concern

    attr_accessor :owner_model, :target_name, :options

    def initialize(owner_model, target_name, options={})
      @owner_model = owner_model
      @target_name = target_name
      @options = options
    end

    def association_model
      @association_model ||= self.class.name.deconstantize.constantize
    end

    def new(owner)
      association_model.new(self, owner)
    end

    def delegate(method_src, method_dst, options={})
      metadata = self
      owner_model.inject_in_layer :associations do
        define_method(method_src) do |*args, &block|
          super(*args, &block) if options[:call_super]
          target = options[:to] == :self ? self : associations[metadata]
          target.__send__(method_dst, *args, &block)
        end
      end
    end

    def hook
      options.assert_valid_keys(*self.class.const_get(:VALID_OPTIONS))
      delegate("#{target_name}=", "#{'polymorphic_' if options[:polymorphic]}write".to_sym)
      delegate("#{target_name}", "#{'polymorphic_' if options[:polymorphic]}read".to_sym)
    end

    def add_callback_for(what)
      instance_eval <<-RUBY, __FILE__, __LINE__ + 1
        if !@added_#{what}
          metadata = self
          owner_model.#{what} { associations[metadata].#{what}_callback }
          @added_#{what} = true
        end
      RUBY
    end

    def get_model_by_name(model_name)
      return model_name if model_name.is_a?(Module)

      model_name = model_name.to_s
      current_module = NoBrainer.rails6? ? @owner_model.module_parent : @owner_model.parent

      return model_name.constantize if current_module == Object
      return model_name.constantize if model_name =~ /^::/
      return model_name.constantize if !current_module.const_defined?(model_name)
      current_module.const_get(model_name)
    end
  end

  included { attr_accessor :metadata, :owner }

  delegate :primary_key, :foreign_key, :foreign_type, :target_name,
           :target_model, :base_criteria, :to => :metadata

  def initialize(metadata, owner)
    @metadata, @owner = metadata, owner
  end

  def assert_target_type(value)
    unless value.is_a?(target_model) || value.nil?
      options = { :attr_name => target_name, :value => value, :type => target_model }
      raise NoBrainer::Error::InvalidType.new(options)
    end
  end
end
