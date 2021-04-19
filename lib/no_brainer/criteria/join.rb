module NoBrainer::Criteria::Join
  extend ActiveSupport::Concern

  included { criteria_option :join, :merge_with => :append_array }

  def join(*values)
    chain(:join => values)
  end

  private

  def _compile_join_ast(value)
    case value
    when Hash then
      value.reduce({}) do |h, (k,v)|
        association = model.association_metadata[k.to_sym]
        raise "`#{k}' must be an association on `#{model}'" unless association
        raise "join() does not support through associations" if association.options[:through]
        raise "join() does not support polymorphic associations" if association.options[:polymorphic]

        criteria = association.base_criteria
        criteria = case v
          when NoBrainer::Criteria then criteria.merge(v)
          when true then criteria
          else criteria.join(v)
        end
        h.merge(association => criteria)
      end
    when Array then value.map { |v| _compile_join_ast(v) }.reduce({}, :merge)
    else _compile_join_ast(value => true)
    end
  end

  def join_ast
    @join_ast ||= _compile_join_ast(@options[:join])
  end

  def _instantiate_model(attrs, options={})
    return super unless @options[:join] && !raw?
    return super if attrs.nil?

    associated_instances = join_ast.map do |association, criteria|
      [association, criteria.send(:_instantiate_model, attrs.delete(association.target_name.to_s))]
    end
    super(attrs, options).tap do |instance|
      associated_instances.each do |association, assoc_instance|
        instance.associations[association].preload([assoc_instance])
      end
    end
  end

  def compile_rql_pass2
    return super unless @options[:join]

    join_ast.reduce(super) do |rql, (association, criteria)|
      rql.concat_map do |doc|
        key = doc[association.eager_load_owner_key]
        RethinkDB::RQL.new.branch(key.default(nil).eq(nil), [],
          criteria.where(association.eager_load_target_key => key).to_rql.map do |assoc_doc|
            doc.merge(association.target_name => assoc_doc)
        end)
      end
    end
  end
end
