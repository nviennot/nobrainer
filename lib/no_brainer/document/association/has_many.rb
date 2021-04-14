class NoBrainer::Document::Association::HasMany
  include NoBrainer::Document::Association::Core

  class Metadata
    VALID_OPTIONS = [:primary_key, :foreign_key, :class_name, :dependent, :scope,
                     :as]
    include NoBrainer::Document::Association::Core::Metadata
    include NoBrainer::Document::Association::EagerLoader::Generic

    def foreign_key
      return options[:foreign_key].try(:to_sym) if options.key?(:foreign_key)
      return :"#{options[:as]}_#{primary_key}" if options[:as]

      :"#{owner_model.name.split('::').last.underscore}_#{primary_key}"
    end

    def foreign_type
      options[:foreign_type].try(:to_sym) || (options[:as] && :"#{options[:as]}_type")
    end

    def primary_key
      options[:primary_key].try(:to_sym) || owner_model.pk_name
    end

    def target_model
      get_model_by_name(options[:class_name] || target_name.to_s.singularize.camelize)
    end

    def base_criteria
      options[:scope] ? target_model.instance_exec(&options[:scope]) : target_model.all
    end

    def inverses
      # We can always infer the inverse association of a has_many relationship,
      # because a belongs_to association cannot have a scope applied on the
      # selector.
      # XXX Without caching, this is going to get CPU intensive quickly, but
      # caching is hard (rails console reload, etc.).
      target_model.association_metadata.values.select do |assoc|
        assoc.is_a?(NoBrainer::Document::Association::BelongsTo::Metadata) and
        assoc.foreign_key == foreign_key                                   and
        assoc.primary_key == primary_key                                   and
        assoc.target_model(target_model).root_class == owner_model.root_class
      end
    end

    def hook
      super

      if options[:scope]
        raise ":scope must be passed a lambda like this: `:scope => ->{ where(...) }'" unless options[:scope].is_a?(Proc)
        raise ':dependent and :scope cannot be used together' if options[:dependent]
      end

      if options[:dependent]
        unless [:destroy, :delete, :nullify, :restrict, nil].include?(options[:dependent])
          raise "Invalid dependent option: `#{options[:dependent].inspect}'. " \
                'Valid options are: :destroy, :delete, :nullify, or :restrict'
        end
        add_callback_for(:before_destroy)
      end
    end

    def eager_load_owner_key;  primary_key; end
    def eager_load_owner_type; foreign_type; end
    def eager_load_target_key; foreign_key; end
  end

  def target_criteria
    @target_criteria ||= begin
      query_criteria = { foreign_key => owner.__send__(primary_key) }

      if metadata.options[:as]
        query_criteria = query_criteria.merge(
          foreign_type => owner.root_class.name
        )
      end

      base_criteria.where(query_criteria).after_find(set_inverse_proc)
    end
  end

  def read
    target_criteria
  end

  def write(new_children)
    raise "You can't assign `#{target_name}'. " \
          "Instead, you must modify delete and create `#{target_model}' manually."
  end

  def loaded?
    target_criteria.cached?
  end

  def preload(new_targets)
    set_inverses_of(new_targets)
    target_criteria._override_cache(new_targets)
  end

  def set_inverses_of(new_targets)
    @inverses ||= metadata.inverses
    return if @inverses.blank?

    new_targets.each do |target|
      # We don't care if target is a parent class where the inverse association
      # is defined, we set the association regardless.
      # The user won't be able to access it since the association accessors are
      # not defined on the parent class.
      @inverses.each { |inverse| target.associations[inverse].preload(self.owner) }
    end
  end

  def set_inverse_proc
    ->(target){ set_inverses_of([target]) if target.is_a?(NoBrainer::Document) }
  end

  def dependent_criteria
    target_criteria.unscoped
  end

  def before_destroy_callback
    case metadata.options[:dependent]
    when :destroy  then dependent_criteria.destroy_all
    when :delete   then dependent_criteria.delete_all
    when :nullify  then dependent_criteria.update_all(foreign_key => nil)
    when :restrict then raise NoBrainer::Error::ChildrenExist unless dependent_criteria.empty?
    end
  end
end
