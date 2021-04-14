class NoBrainer::Document::Association::BelongsTo
  include NoBrainer::Document::Association::Core

  class Metadata
    VALID_OPTIONS = %i[
      primary_key foreign_key foreign_type class_name foreign_key_store_as
      index validates required uniq unique polymorphic
    ]

    include NoBrainer::Document::Association::Core::Metadata
    include NoBrainer::Document::Association::EagerLoader::Generic

    def foreign_key
      options[:foreign_key].try(:to_sym) || :"#{target_name}_#{primary_key}"
    end

    def foreign_type
      return nil unless options[:polymorphic]

      options[:foreign_type].try(:to_sym) || (target_name && :"#{target_name}_type")
    end

    def primary_key
      # We default the primary_key to `:id' and not `target_model.pk_name',
      # because we don't want to require the target_model to be already loaded.
      # (We want the ability to load models in any order).
      # Using target_model.pk_name and allowing lazy loading of models is
      # difficult due to the inexistant API to remove validations if the
      # foreign_key name was to be changed as the pk_name gets renamed.
      return options[:primary_key].to_sym if options[:primary_key]

      NoBrainer::Document::PrimaryKey::DEFAULT_PK_NAME.tap do |default_pk_name|
        # We'll try to give a warning when we see a different target pk name (best effort).
        real_pk_name = target_model.pk_name rescue nil
        if real_pk_name && real_pk_name != default_pk_name
          raise "Please specify the primary_key name on the following belongs_to association as such:\n" +
                "  belongs_to :#{target_name}, :primary_key => :#{real_pk_name}"
        end
      end
    end

    def target_model(target_class = nil)
      return if options[:polymorphic] && target_class.nil?

      model_name = options[:class_name] || target_name.to_s.camelize
      model_name = target_class if options[:polymorphic]

      get_model_by_name(model_name)
    end

    def base_criteria(target_class = nil)
      target_model(target_class)&.without_ordering
    end

    def hook
      super

      # TODO set the type of the foreign key to be the same as the target's primary key
      if owner_model.association_metadata.values.any? { |assoc|
          assoc.is_a?(self.class) && assoc != self && assoc.foreign_key == foreign_key }
        raise "Cannot declare `#{target_name}' in #{owner_model}: the foreign_key `#{foreign_key}' is already used"
      end

      if options[:polymorphic] && options[:class_name]
        raise 'You cannot set class_name on a polymorphic belongs_to'
      end

      owner_model.field(foreign_type) if options[:polymorphic]
      owner_model.field(foreign_key, :store_as => options[:foreign_key_store_as], :index => options[:index])

      unless options[:validates] == false
        owner_model.validates(target_name, options[:validates]) if options[:validates]

        uniq = options[:uniq] || options[:unique]
        if uniq
          owner_model.validates(foreign_key, :uniqueness => uniq)
        end

        if options[:required]
          owner_model.validates(target_name, :presence => options[:required])
        else
          # Always validate the foreign_key if not nil.
          owner_model.validates_each(foreign_key) do |doc, attr, value|
            if !value.nil? && value != doc.pk_value && doc.read_attribute_for_validation(target_name).nil?
              doc.errors.add(attr, :invalid_foreign_key, :target_model => target_model, :primary_key => primary_key)
            end
          end
        end
      end

      delegate("#{foreign_key}=", :assign_foreign_key, :call_super => true)
      delegate("#{target_name}_changed?", "#{foreign_key}_changed?", :to => :self)
      add_callback_for(:after_validation)
    end

    def cast_attr(k, v)
      case v
      when target_model then [foreign_key, v.__send__(primary_key)]
      when nil          then [foreign_key, nil]
      else
        opts = { :model => owner_model, :attr_name => k, :type => target_model, :value => v }
        raise NoBrainer::Error::InvalidType.new(opts)
      end
    end

    def eager_load_owner_key;  foreign_key; end
    def eager_load_owner_type; foreign_type; end
    def eager_load_target_key; primary_key; end
  end

  # Note:
  # @target_container is an array to distinguish the following cases:
  # * target is not loaded, but perhaps present in the db.
  # * we already tried to load target, but it wasn't present in the db.

  def assign_foreign_key(value)
    @target_container = nil
  end

  def polymorphic_read
    return target if loaded?

    target_class = owner.read_attribute(foreign_type)

    if fk = owner.read_attribute(foreign_key)
      preload(base_criteria(target_class)&.where(primary_key => fk)&.first)
    end
  end

  def read
    return target if loaded?

    if fk = owner.read_attribute(foreign_key)
      preload(base_criteria.where(primary_key => fk).first)
    end
  end

  def polymorphic_write(target)
    owner.write_attribute(foreign_key, target.try(primary_key))
    owner.write_attribute(foreign_type, target.root_class.name)
    preload(target)
  end

  def write(target)
    assert_target_type(target)
    owner.write_attribute(foreign_key, target.try(primary_key))
    preload(target)
  end

  def preload(targets)
    @target_container = [*targets] # the * is for the generic eager loading code
    target
  end

  def target
    @target_container.first
  end

  def loaded?
    !@target_container.nil?
  end

  def after_validation_callback
    if loaded? && target && !target.persisted? && target != owner
      raise NoBrainer::Error::AssociationNotPersisted.new("#{target_name} must be saved first")
    end
  end
end
