module NoBrainer::Criteria::Where
  extend ActiveSupport::Concern
  include ActiveModel::ForbiddenAttributesProtection

  included do
    criteria_option :where_ast, :merge_with => NoBrainer::Criteria::Where.method(:merge_where_ast)
    criteria_option :without_distinct, :merge_with => :set_scalar
  end

  def where(*args, &block)
    chain(:where_ast => parse_clause([*args, block].compact))
  end

  def _where(*args, &block)
    chain(:where_ast => parse_clause([*args, block].compact, :unsafe => true))
  end

  def self.merge_where_ast(a, b)
    (a ? MultiOperator.new(:and, [a, b]) : b).simplify
  end

  def where_present?
    finalized_criteria.options[:where_ast].try(:clauses).present?
  end

  def where_indexed?
    where_index_name.present?
  end

  def where_index_name
    index = where_index_finder.strategy.try(:index)
    index.is_a?(Array) ? index.map(&:name) : index.try(:name)
  end

  def where_index_type
    where_index_finder.strategy.try(:rql_op)
  end

  def without_distinct(value = true)
    # helper for delete_all which can't operate on distinct
    chain(:without_distinct => value)
  end

  private

  class MultiOperator < Struct.new(:op, :clauses)
    def simplify
      clauses = self.clauses.map(&:simplify)
      if clauses.size == 1 && clauses.first.is_a?(self.class)
        return clauses.first
      end

      same_op_clauses, other_clauses = clauses.partition do |v|
        v.is_a?(self.class) && (v.clauses.size == 1 || v.op == self.op)
      end
      simplified_clauses = other_clauses + same_op_clauses.flat_map(&:clauses)
      simplified_clauses = BinaryOperator.simplify_clauses(op, simplified_clauses.uniq)
      self.class.new(op, simplified_clauses)
    end

    def to_rql(doc)
      case op
      when :and then clauses.map { |c| c.to_rql(doc) }.reduce(:&)
      when :or  then clauses.map { |c| c.to_rql(doc) }.reduce(:|)
      end
    end
  end

  class BinaryOperator < Struct.new(:key_path, :key_modifier, :op, :value, :model, :casted_values)
    def self.get_candidate_clauses(clauses, *types)
      clauses.select { |c| c.is_a?(self) && types.include?(c.op) }
    end

    def self.simplify_clauses(op, ast_clauses)
      # This code assumes that simplfy() has already been called on all clauses.
      if op == :or
        eq_clauses = get_candidate_clauses(ast_clauses, :in, :eq)
        new_clauses = eq_clauses.group_by { |c| [c.key_path, c.key_modifier] }.map do |(key_path, key_modifier), clauses|
          if key_modifier.in?([:scalar, :any]) && clauses.size > 1
            values = clauses.flat_map { |c| c.op == :in ? c.value : [c.value] }.uniq
            [BinaryOperator.new(key_path, key_modifier, :in, values, clauses.first.model, true)]
          else
            clauses
          end
        end.flatten(1)

        if new_clauses.size != eq_clauses.size
          ast_clauses = ast_clauses - eq_clauses + new_clauses
        end
      end

      ast_clauses
    end

    def simplify
      new_key_path = cast_key_path(key_path)
      new_key_modifier, new_op, new_value = case op
        when :in then
          case value
          when Range then [key_modifier, :between, (cast_value(value.min)..cast_value(value.max))]
          when Array then [key_modifier, :in, value.map(&method(:cast_value)).uniq]
          else raise ArgumentError.new "`in' takes an array/range, not #{value}"
          end
        when :between then [key_modifier, op, (cast_value(value.min)..cast_value(value.max))]
        when :include then ensure_scalar_for(op); [:any, :eq, cast_value(value)]
        when :defined, :undefined then ensure_scalar_for(op); [key_modifier, op, cast_value(value)]
        when :during then [key_modifier, op, [cast_value(value.first), cast_value(value.last)]]
        else [key_modifier, op, cast_value(value)]
      end
      BinaryOperator.new(new_key_path, new_key_modifier, new_op, new_value, model, true)
    end

    def to_rql(doc)
      key_path = [model.lookup_field_alias(self.key_path.first), *self.key_path[1..-1]]

      doc = key_path[0..-2].reduce(doc) { |d,k| d[k] }
      key = key_path.last

      case key_modifier
      when :scalar then
        case op
        when :defined   then  value ? doc.has_fields(key) : doc.has_fields(key).not
        when :undefined then !value ? doc.has_fields(key) : doc.has_fields(key).not
        else to_rql_scalar(doc[key])
        end
      when :any then doc[key].map { |lvalue| to_rql_scalar(lvalue) }.contains(true)
      when :all then doc[key].map { |lvalue| to_rql_scalar(lvalue) }.contains(false).not
      end
    end

    def to_rql_scalar(lvalue)
      case op
      when :between    then (lvalue >= value.min) & (lvalue <= value.max)
      when :in         then RethinkDB::RQL.new.expr(value).contains(lvalue)
      when :intersects then lvalue.intersects(value.to_rql)
      when :during     then lvalue.during(value.first, value.last)
      when :near
        # XXX options[:max_results] is not used, seems to be a workaround of rethinkdb index implementation.
        circle = value[:circle]
        RethinkDB::RQL.new.distance(lvalue, circle.center.to_rql, circle.options) <= circle.radius
      else lvalue.__send__(op, value)
      end
    end

    def compatible_with_index?(index)
      [key_modifier, index.multi].in?([[:any, true], [:scalar, false]])
    end

    private

    def ensure_scalar_for(op)
      raise "Incorrect use of `#{op}' and `#{key_modifier}'" if key_modifier != :scalar
    end

    def cast_value(value)
      return value if casted_values

      case op
      when :defined, :undefined then NoBrainer::Boolean.nobrainer_cast_user_to_model(value)
      when :intersects
        raise "Use a geo object with `intersects`" unless value.is_a?(NoBrainer::Geo::Base)
        value
      when :near
        # TODO enforce key is a geo type
        case value
        when Hash
          options = NoBrainer::Geo::Base.normalize_geo_options(value)

          options[:radius] = options.delete(:max_distance) if options[:max_distance]
          options[:radius] = options.delete(:max_dist) if options[:max_dist]
          options[:center] = options.delete(:point) if options[:point]

          unless options[:circle]
            unless options[:center] && options[:radius]
              raise "`near' takes something like {:center => P, :radius => d}"
            end
            { :circle => NoBrainer::Geo::Circle.new(options), :max_results => options[:max_results] }
          end
        when NoBrainer::Geo::Circle then { :circle => value }
        else raise "Incorrect use of `near': rvalue must be a hash or a circle"
        end
      else
        # 1) Box value in array if we have an any/all modifier
        # 2) Box value in hash if we have a nested query.
        box_value = key_modifier.in?([:any, :all]) || op == :include
        value = [value] if box_value
        k_v = key_path.reverse.reduce(value) { |v,k| {k => v} }.first
        k_v = model.association_user_to_model_cast(*k_v)
        value = model.cast_user_to_db_for(*k_v)
        value = key_path[1..-1].reduce(value) { |h,k| h[k] }
        value = value.first if box_value
        value
      end
    end

    def cast_key_path(key_path)
      return key_path if casted_values

      if key_path.size == 1
        k, _v = model.association_user_to_model_cast(key_path.first, nil)
        key_path = [k]
      end

      model.ensure_valid_key!(key_path.first)
      key_path
    end
  end

  class UnaryOperator < Struct.new(:op, :clause)
    def simplify
      simplified_clause = self.clause.simplify

      case simplified_clause
      when UnaryOperator then
        case [self.op, simplified_clause.op]
        when [:not, :not] then simplified_clause.clause
        else self.class.new(op, simplified_clause)
        end
      else self.class.new(op, simplified_clause)
      end
    end

    def to_rql(doc)
      case op
      when :not then clause.to_rql(doc).not
      end
    end
  end

  class Lambda < Struct.new(:value)
    def simplify
      self
    end

    def to_rql(doc)
      value.call(doc)
    end
  end

  def parse_clause(clause, options={})
    clause = sanitize_for_mass_assignment(clause)
    case clause
    when Array then MultiOperator.new(:and, clause.map { |c| parse_clause(c, options) })
    when Hash  then MultiOperator.new(:and, clause.map { |k,v| parse_clause_stub(k, v, options) })
    when Proc  then Lambda.new(clause)
    when Symbol::Decoration
      case clause.args.size
      when 1 then parse_clause_stub(clause, clause.args.first, options)
      when 2 then parse_clause_stub(clause, clause.args, options)
      else raise "Invalid argument: #{clause}"
      end
    else raise "Invalid clause: #{clause}"
    end
  end

  def parse_clause_stub(key, value, options={})
    case key
    when :and  then parse_multi_value(:and, value, false, options)
    when :or   then parse_multi_value(:or,  value, false, options)
    when :_and then parse_multi_value(:and, value, true, options)
    when :_or  then parse_multi_value(:or,  value, true, options)
    when :not  then UnaryOperator.new(:not, parse_clause(value, options))
    when String, Symbol then
      case value
      when Hash then parse_clause(value, options.merge(:nested_prefix => (options[:nested_prefix] || []) + [key.to_sym]))
      else instantiate_binary_op(key.to_sym, :eq, value, options)
      end
    when Symbol::Decoration then
      # The :eq operator can have only one arg
      if key.decorator == :eq && value.is_a?(Array) && value.size > 1
        raise "Invalid key: #{key}"
      end

      case key.decorator
      when :any, :all, :not then instantiate_binary_op(key, :eq, value, options)
      when :gte then instantiate_binary_op(key.symbol, :ge, value, options)
      when :lte then instantiate_binary_op(key.symbol, :le, value, options)
      else instantiate_binary_op(key.symbol, key.decorator, value, options)
      end
    else raise "Invalid key: #{key}"
    end
  end

  def parse_multi_value(op, value, multi_safe, options={})
    raise "The `#{op}' operator takes an array as argument" unless value.is_a?(Array)
    if value.size == 1 && value.first.is_a?(Hash) && !multi_safe
      raise "The `#{op}' operator was provided an array with a single hash element.\n" +
            "In Ruby, [:a => :b, :c => :d] means [{:a => :b, :c => :d}] which is not the same as [{:a => :b}, {:c => :d}].\n" +
            "To prevent mistakes, the former construct is prohibited as you probably mean the latter.\n" +
            "However, if you know what you are doing, you can use the `_#{op}' operator instead."
    end
    MultiOperator.new(op, value.map { |v| parse_clause(v, options) })
  end

  def translate_regexp_to_re2_syntax(value)
    # Ruby always uses what RE2 calls "multiline mode" (the "m" flag),
    # meaning that "foo\nbar" matches /^bar$/.
    #
    # Ruby's /m modifier means that . matches \n and corresponds to RE2's "s" flag.

    flags = "m"
    flags << "s" if value.options & Regexp::MULTILINE != 0
    flags << "i" if value.options & Regexp::IGNORECASE != 0

    "(?#{flags})#{value.source}"
  end

  def instantiate_binary_op(key, op, value, options={})
    op, value = case value
                when Range  then [:between, value]
                when Regexp then [:match, translate_regexp_to_re2_syntax(value)]
                else [:eq, value]
                end if op == :eq

    nested_prefix = options[:nested_prefix] || []

    tail_args = [op, value, self.model, !!options[:unsafe]]

    case key
    when Symbol::Decoration
      raise "Use only one .not, .all or .any modifiers in the query" if key.symbol.is_a?(Symbol::Decoration)
      case key.decorator
        when :any, :all then BinaryOperator.new(nested_prefix + [key.symbol], key.decorator, *tail_args)
        when :not       then UnaryOperator.new(:not, BinaryOperator.new(nested_prefix + [key.symbol], :scalar, *tail_args))
      end
    else BinaryOperator.new(nested_prefix + [key], :scalar, *tail_args)
    end
  end

  class IndexFinder < Struct.new(:criteria, :ast, :strategy)
    class Strategy < Struct.new(:index_finder, :rql_op, :index, :ast, :rql_proc); end
    class IndexStrategy < Struct.new(:index_finder, :criteria_ast, :optimized_clauses, :index, :rql_op, :rql_args, :rql_options)
      def ast
        MultiOperator.new(criteria_ast.op, criteria_ast.clauses - optimized_clauses)
      end

      def rql_proc
        lambda do |rql|
          return RethinkDB::RQL.new.expr([]) if rql_op == :get_all && rql_args.empty?

          opt = (rql_options || {}).merge(:index => index.aliased_name)
          r = rql.__send__(rql_op, *rql_args, opt)
          r = r.map { |i| i['doc'] } if rql_op == :get_nearest
          r = r.distinct if index.multi && !index_finder.criteria.options[:without_distinct]
          r
        end
      end
    end

    def get_candidate_clauses(*types)
      BinaryOperator.get_candidate_clauses(ast.clauses, *types)
    end

    def get_usable_indexes(options={})
      indexes = criteria.model.indexes.values
      options.each { |k,v| indexes = indexes.select { |i| v == i.__send__(k) } }
      if criteria.options[:use_index] && criteria.options[:use_index] != true
        indexes = indexes.select { |i| i.name == criteria.options[:use_index].to_sym }
      end
      indexes
    end

    def find_strategy_canonical
      clauses = get_candidate_clauses(:eq, :in, :between, :near, :intersects, :defined)
      return nil unless clauses.present?

      usable_indexes = Hash[get_usable_indexes.map { |i| [[i.name], i] }]
      clauses.map do |clause|
        index = usable_indexes[clause.key_path]
        next unless index && clause.compatible_with_index?(index)
        next unless index.geo == [:near, :intersects].include?(clause.op)

        args = case clause.op
          when :intersects then [:get_intersecting, clause.value.to_rql]
          when :near
            options = clause.value.dup
            circle = options.delete(:circle)
            options.delete(:max_results) if options[:max_results].nil?
            options[:max_dist] = circle.radius
            [:get_nearest, circle.center.to_rql, circle.options.merge(options)]
          when :eq      then [:get_all, [clause.value]]
          when :in      then [:get_all, clause.value]
          when :defined then
            next unless clause.value == true
            next unless clause.key_modifier == :scalar && index.multi == false
            [:between, [RethinkDB::RQL.new.minval, RethinkDB::RQL.new.maxval],
             :left_bound => :open, :right_bound => :open]
          when :between then [:between, [clause.value.min, clause.value.max],
                              :left_bound => :closed, :right_bound => :closed]
        end
        IndexStrategy.new(self, ast, [clause], index, *args)
      end.compact.sort_by { |strat| usable_indexes.values.index(strat.index) }.first
    end

    def find_strategy_compound
      clauses = Hash[get_candidate_clauses(:eq).map { |c| [c.key_path, c] }]
      return nil unless clauses.present?

      get_usable_indexes(:kind => :compound, :geo => false, :multi => false).each do |index|
        indexed_clauses = index.what.map { |field| clauses[[field]] }
        if indexed_clauses.all? { |c| c.try(:compatible_with_index?, index) }
          return IndexStrategy.new(self, ast, indexed_clauses, index, :get_all, [indexed_clauses.map(&:value)])
        end

        # use partial compound index if possible
        partial_clauses = indexed_clauses.compact
        pad = indexed_clauses.length - partial_clauses.length
        if partial_clauses.any? && partial_clauses.all? { |c| c.try(:compatible_with_index?, index) } &&
          ((clauses.values & partial_clauses) == clauses.values) && indexed_clauses.last(pad).all?(&:nil?)
          left_bound  = partial_clauses.map(&:value) + Array.new(pad, RethinkDB::RQL.new.minval)
          right_bound = partial_clauses.map(&:value) + Array.new(pad, RethinkDB::RQL.new.maxval)
          return IndexStrategy.new(self, ast, partial_clauses, index, :between, [left_bound, right_bound], { left_bound: :open, right_bound: :open })
        end
      end
      return nil
    end

    def find_strategy_hidden_between
      clauses = get_candidate_clauses(:gt, :ge, :lt, :le).group_by(&:key_path)
      return nil unless clauses.present?

      get_usable_indexes(:geo => false).each do |index|
        matched_clauses = clauses[[index.name]].try(:select) { |c| c.compatible_with_index?(index) }
        next unless matched_clauses.present?

        op_clauses = Hash[matched_clauses.map { |c| [c.op, c] }]
        left_bound  = op_clauses[:gt] || op_clauses[:ge]
        right_bound = op_clauses[:lt] || op_clauses[:le]

        # XXX we must keep only one bound when using `any', otherwise we get different semantics.
        right_bound = nil if index.multi && left_bound && right_bound

        options = {}
        options[:left_bound]  = {:gt => :open, :ge => :closed}[left_bound.op]  if left_bound
        options[:right_bound] = {:lt => :open, :le => :closed}[right_bound.op] if right_bound

        return IndexStrategy.new(self, ast, [left_bound, right_bound].compact, index, :between,
                                 [left_bound  ? left_bound.try(:value)  : RethinkDB::RQL.new.minval,
                                  right_bound ? right_bound.try(:value) : RethinkDB::RQL.new.maxval], options)
      end
      return nil
    end

    def find_strategy_union
      strategies = ast.clauses.map do |inner_ast|
        inner_ast = MultiOperator.new(:and, [inner_ast]) unless inner_ast.is_a?(MultiOperator)
        raise 'fatal' unless inner_ast.op == :and
        self.class.new(criteria, inner_ast).find_strategy
      end

      return nil if strategies.any?(&:nil?)

      rql_proc = lambda do |base_rql|
        strategies.map do |strategy|
          rql = strategy.rql_proc.call(base_rql)
          rql = rql.filter { |doc| strategy.ast.to_rql(doc) } if strategy.ast.try(:clauses).present?
          rql
        end.reduce(:union).distinct
      end

      Strategy.new(self, :union, strategies.map(&:index), nil, rql_proc)
    end

    def find_strategy
      return nil unless ast.try(:clauses).present? && !criteria.without_index?
      case ast.op
      when :and then find_strategy_compound || find_strategy_canonical || find_strategy_hidden_between
      when :or  then find_strategy_union
      end
    end

    def find_strategy!
      self.strategy = find_strategy
    end
  end

  def where_index_finder
    return finalized_criteria.__send__(:where_index_finder) unless finalized?
    @where_index_finder ||= IndexFinder.new(self, @options[:where_ast]).tap(&:find_strategy!)
  end

  def compile_rql_pass1
    rql = super
    rql = where_index_finder.strategy.rql_proc.call(rql) if where_indexed?
    rql
  end

  def compile_rql_pass2
    rql = super
    ast = where_indexed? ? where_index_finder.strategy.ast : @options[:where_ast]
    rql = rql.filter { |doc| ast.to_rql(doc) } if ast.try(:clauses).present?
    rql
  end
end
