require 'spec_helper'

describe 'types' do
  before { load_simple_document }
  before { SimpleDocument.field :field1, field_options }
  let(:field_options) { { :type => type } }
  let(:doc) { SimpleDocument.new }

  context 'when using String type' do
    let(:type) { String }

    context 'when fed with a symbol, string' do
      it 'casts the value' do
        doc.field1 = 'ohai'
        doc.field1.should == 'ohai'
        doc.valid?.should == true
        doc.field1 = :ohai
        doc.field1.should == 'ohai'
        doc.valid?.should == true
      end
    end

    context 'when fed with other values' do
      it 'invalidates the document and keep the original value' do
        doc.field1 = (1..2)
        doc.field1.should == (1..2)
        doc.valid?.should == false
        doc.errors.full_messages.first.should == "Field1 should be a string"

        doc.field1 = Symbol
        doc.field1.should == Symbol
        doc.valid?.should == false
        doc.errors.full_messages.first.should == "Field1 should be a string"
      end
    end

    it 'type checks and casts on length' do
      doc.field1 = "x" * NoBrainer::Config.max_string_length
      doc.field1.should == "x" * NoBrainer::Config.max_string_length
      doc.valid?.should == true

      doc.field1 = "x" * (NoBrainer::Config.max_string_length + 1)
      doc.field1.should == "x" * (NoBrainer::Config.max_string_length + 1)
      doc.valid?.should == false
      doc.errors.full_messages.first.should == "Field1 is too long (maximum is #{NoBrainer::Config.max_string_length} characters)"
    end
  end

  context 'when using Text type' do
    let(:type) { SimpleDocument::Text }

    it 'type checks and casts' do
        doc.field1 = 'ohai'
        doc.field1.should == 'ohai'
        doc.valid?.should == true
        doc.field1 = :ohai
        doc.field1.should == :ohai
        doc.valid?.should == false
    end

    it 'type does not checks length' do
      doc.field1 = "x" * (NoBrainer::Config.max_string_length + 1)
      doc.field1.should == "x" * (NoBrainer::Config.max_string_length + 1)
      doc.valid?.should == true
    end
  end

  context 'when using Integer type' do
    let(:type) { Integer }

    it 'type checks and casts' do
      doc.field1 = 1
      doc.field1.should == 1
      doc.valid?.should == true
      doc.field1 = '1'
      doc.field1.should == 1
      doc.valid?.should == true
      doc.field1 = '+1 '
      doc.field1.should == 1
      doc.valid?.should == true
      doc.field1 = ' -1'
      doc.field1.should == -1
      doc.valid?.should == true

      doc.field1 = '=1'
      doc.field1.should == '=1'
      doc.valid?.should == false

      doc.field1 = :hello
      doc.field1.should == :hello
      doc.valid?.should == false

      doc.field1 = 2**100
      doc.field1.should == 2**100
      doc.valid?.should == true
      doc.field1 = (2**100).to_s
      doc.field1.should == 2**100
      doc.valid?.should == true

      doc.field1 = 1.0
      doc.field1.should == 1
      doc.valid?.should == true
      doc.field1 = 1.1
      doc.field1.should == 1.1
      doc.valid?.should == false
      doc.field1 = ''
      doc.field1.should == ''
      doc.valid?.should == false
    end
  end

  context 'when using Float type' do
    let(:type) { Float }

    it 'type checks and casts' do
      doc.field1 = 1.1
      doc.field1.should == 1.1
      doc.valid?.should == true
      doc.field1 = '1'
      doc.field1.should == 1.0
      doc.valid?.should == true
      doc.field1 = '1.0'
      doc.field1.should == 1.0
      doc.valid?.should == true
      doc.field1 = '1.00'
      doc.field1.should == 1.00
      doc.valid?.should == true
      doc.field1 = '1.1'
      doc.field1.should == 1.1
      doc.valid?.should == true
      doc.field1 = '1.100'
      doc.field1.should == 1.1
      doc.valid?.should == true
      doc.field1 = '0.0'
      doc.field1.should == 0.0
      doc.valid?.should == true
      doc.field1 = '0'
      doc.field1.should == 0
      doc.valid?.should == true

      doc.field1 = '+1.1 '
      doc.field1.should == 1.1
      doc.valid?.should == true
      doc.field1 = ' -1.1'
      doc.field1.should == -1.1
      doc.valid?.should == true

      doc.field1 = '=1.1'
      doc.field1.should == '=1.1'
      doc.valid?.should == false

      doc.field1 = 'a0'
      doc.field1.should == 'a0'
      doc.valid?.should == false
      doc.field1 = ''
      doc.field1.should == ''
      doc.valid?.should == false

      doc.field1 = 1
      doc.field1.should == 1.0
      doc.valid?.should == true
    end
  end

  context 'when using Boolean type' do
    let(:type) { SimpleDocument::Boolean }

    it 'provides a ? method' do
      doc.field1 = true
      doc.field1?.should == true
      doc.field1 = false
      doc.field1?.should == false
    end

    it 'type checks and casts' do
      doc.field1 = true
      doc.field1.should == true
      doc.valid?.should == true
      doc.field1 = false
      doc.field1.should == false
      doc.valid?.should == true

      doc.field1 = ' tRue'
      doc.field1.should == true
      doc.valid?.should == true
      doc.field1 = 'falSe '
      doc.field1.should == false
      doc.valid?.should == true

      doc.field1 = 't'
      doc.field1.should == true
      doc.valid?.should == true
      doc.field1 = 'f'
      doc.field1.should == false
      doc.valid?.should == true

      doc.field1 = 'yEs'
      doc.field1.should == true
      doc.valid?.should == true
      doc.field1 = 'no'
      doc.field1.should == false
      doc.valid?.should == true

      doc.field1 = '1'
      doc.field1.should == true
      doc.valid?.should == true
      doc.field1 = '0'
      doc.field1.should == false
      doc.valid?.should == true

      doc.field1 = 1
      doc.field1.should == true
      doc.valid?.should == true
      doc.field1 = 0
      doc.field1.should == false
      doc.valid?.should == true

      doc.field1 = '2'
      doc.field1.should == '2'
      doc.valid?.should == false
      doc.field1 = 'blah'
      doc.field1.should == 'blah'
      doc.valid?.should == false
      doc.field1 = ''
      doc.field1.should == ''
      doc.valid?.should == false
      doc.field1 = 2
      doc.field1.should == 2
      doc.valid?.should == false
    end
  end

  context 'when using Binary type' do
    let(:type) { SimpleDocument::Binary }
    let(:data) { 255.times.map { |i| i.chr }.join }

    it 'type checks and casts' do
      doc.field1 = 'hello'
      doc.valid?.should == true
      doc.field1 = 123
      doc.valid?.should == false
      doc.field1 = :hello
      doc.valid?.should == false
      doc.field1 = data
      doc.valid?.should == true
    end

    it 'reads back a binary from the db' do
      doc.field1 = data
      doc.save
      doc.reload
      doc.field1.should be_a(RethinkDB::Binary)
      doc.field1.should == RethinkDB::Binary.new(data)
    end
  end

  context 'when using Symbol type' do
    let(:type) { Symbol }

    it 'type checks and casts' do
      doc.field1 = :ohai
      doc.field1.should == :ohai
      doc.valid?.should == true
      doc.field1 = 'ohai'
      doc.field1.should == :ohai
      doc.valid?.should == true
      doc.field1 = '   ohai   '
      doc.field1.should == :ohai
      doc.valid?.should == true
      doc.field1 = 123
      doc.field1.should == 123
      doc.valid?.should == false
      doc.field1 = ''
      doc.field1.should == ''
      doc.valid?.should == false
    end

    it 'reads back a symbol from the db' do
      doc.field1 = :ohai
      doc.save
      doc.reload
      doc.field1.should == :ohai

      doc.field1 = nil
      doc.save
      doc.reload
      doc.field1.should == nil

      NoBrainer.run { doc.selector.update(:field1 => 1) }
      doc.reload
      doc.field1.should == :"1"
    end
  end

  context 'when using Time type' do
    let(:type) { Time }

    it 'type checks and casts' do
      now = Time.at(Time.now.to_i)

      doc.field1 = now
      doc.field1.should == now
      doc.valid?.should == true

      doc.field1 = "11-11-1111"
      doc.field1.should == "11-11-1111"
      doc.valid?.should == false

      doc.field1 = "hello"
      doc.field1.should == "hello"
      doc.valid?.should == false

      doc.field1 = 123
      doc.field1.should == 123
      doc.valid?.should == false

      doc.field1 = "2014-06-26T15:34:12-02:00"
      doc.field1.should == Time.parse("2014-06-26T15:34:12-02:00")
      doc.valid?.should == true

      doc.field1 = "  2014-06-26T15:34:12-02:00  "
      doc.field1.should == Time.parse("2014-06-26T15:34:12-02:00")
      doc.valid?.should == true

      doc.field1 = "2014-06-26 T 15:34:12-02:00"
      doc.field1.should == "2014-06-26 T 15:34:12-02:00"
      doc.valid?.should == false

      doc.field1 = "2014-06-26x15:34:12-02:00"
      doc.field1.should == "2014-06-26x15:34:12-02:00"
      doc.valid?.should == false

      doc.field1 = "2014-06-26T15:34:12Z"
      doc.field1.should == Time.parse("2014-06-26T15:34:12Z")
      doc.valid?.should == true

      doc.field1 = now.iso8601
      doc.field1.should == now
      doc.valid?.should == true

      doc.field1 = now.utc.iso8601
      doc.field1.should == now.utc
      doc.valid?.should == true
    end unless NoBrainer.jruby? # works locally, but not on travis?

    context 'when using different timezones' do
      let(:time) { Time.new(2002, 10, 31, 2, 2, 2, "+02:00") }

      before do
        NoBrainer.configure do |config|
          config.user_timezone = user_timezone
          config.db_timezone = db_timezone
        end
      end

      context 'when user_timezone is unchanged' do
        let(:user_timezone) { :unchanged }
        let(:db_timezone)   { :unchanged }

        it 'user inputs timezone does not change' do
          doc.field1 = time
          doc.field1.utc_offset.should == time.utc_offset
        end
      end

      context 'when user_timezone is local' do
        let(:user_timezone) { :local }
        let(:db_timezone)   { :unchanged }

        it 'user inputs timezone changes to local' do
          doc.field1 = time
          doc.field1.utc_offset.should == time.utc.getlocal.utc_offset
        end
      end

      context 'when user_timezone is utc' do
        let(:user_timezone) { :utc }
        let(:db_timezone)   { :unchanged }

        it 'user inputs timezone changes to utc' do
          doc.field1 = time
          doc.field1.utc_offset.should == time.utc.utc_offset
        end
      end

      context 'when db_timezone is unchanged' do
        let(:user_timezone) { :unchanged }
        let(:db_timezone)   { :unchanged }

        it 'db timezone does not change' do
          doc.field1 = time
          doc.save
          r = NoBrainer.run { SimpleDocument.rql_table }
          db_time = r.first['field1']
          db_time.utc_offset.should == time.utc_offset
        end
      end

      context 'when db_timezone is local' do
        let(:user_timezone) { :unchanged }
        let(:db_timezone)   { :local }

        it 'db timezone changes to local' do
          doc.field1 = time
          doc.save
          r = NoBrainer.run { SimpleDocument.rql_table }
          db_time = r.first['field1']
          db_time.utc_offset.should == time.utc.getlocal.utc_offset
        end
      end

      context 'when db_timezone is utc' do
        let(:user_timezone) { :unchanged }
        let(:db_timezone)   { :utc }

        it 'db timezone changes to utc' do
          doc.field1 = time
          doc.save
          r = NoBrainer.run { SimpleDocument.rql_table }
          db_time = r.first['field1']
          db_time.utc_offset.should == time.utc.utc_offset
        end
      end

      context 'when user_timezone is unchanged' do
        let(:user_timezone) { :unchanged }
        let(:db_timezone)   { :unchanged }


        it 'db reads timezone does not change' do
          NoBrainer.run { SimpleDocument.rql_table.insert(:field1 => time) }
          SimpleDocument.first.field1.utc_offset.should == time.utc_offset
        end
      end

      context 'when user_timezone is local' do
        let(:user_timezone) { :local }
        let(:db_timezone)   { :unchanged }

        it 'db reads timezone changes to local' do
          NoBrainer.run { SimpleDocument.rql_table.insert(:field1 => time) }
          SimpleDocument.first.field1.utc_offset.should == time.utc.getlocal.utc_offset
        end
      end

      context 'when user_timezone is utc' do
        let(:user_timezone) { :utc }
        let(:db_timezone)   { :unchanged }

        it 'db reads timezone changes to utc' do
          NoBrainer.run { SimpleDocument.rql_table.insert(:field1 => time) }
          SimpleDocument.first.field1.utc_offset.should == time.utc.utc_offset
        end
      end
    end
  end

  context 'when using Date type' do
    let(:type) { Date }

    it 'type checks and casts' do
      today = Date.today

      doc.field1 = today
      doc.field1.should == today
      doc.valid?.should == true

      doc.field1 = "2014-06-26T15:34:12-02:00"
      doc.field1.should == "2014-06-26T15:34:12-02:00"
      doc.valid?.should == false

      doc.field1 = 123
      doc.field1.should == 123
      doc.valid?.should == false

      doc.field1 = "2014-06-26"
      doc.field1.should == Date.parse("2014-06-26")
      doc.valid?.should == true

      doc.field1 = nil
      doc.save
      doc.reload
      doc.field1.should == nil

      doc.field1 = "2014-06-26"
      doc.save
      doc.reload
      doc.field1.should == Date.parse("2014-06-26")

      SimpleDocument.where(:field1 => Date.parse("2014-06-26")).count.should == 1
    end
  end

  context 'when using a non implemented type' do
    let(:type) { nil }
    before { define_class(:CustomType) { } }
    before { SimpleDocument.field :field1, :type => CustomType }

    it 'type checks' do
      doc.field1 = CustomType.new
      doc.valid?.should == true
      doc.field1 = 123
      doc.valid?.should == false
      doc.errors.full_messages.first.should == "Field1 should be a custom type"
    end
  end

  context 'when using a custom type' do
    let(:type) { nil }
    before do
      define_class :Point, Struct.new(:x, :y) do
        def self.nobrainer_cast_user_to_model(value)
          case value
          when Point then value
          when Hash  then new(value[:x] || value['x'], value[:y] || value['y'])
          else raise NoBrainer::Error::InvalidType
          end
        end

        def self.nobrainer_cast_db_to_model(value)
          Point.new(value['x'], value['y'])
        end

        def self.nobrainer_cast_model_to_db(value)
          {'x' => value.x, 'y' => value.y}
        end
      end
    end
    before { SimpleDocument.field :field1, :type => Point }

    it 'type checks' do
      doc.field1 = Point.new
      doc.valid?.should == true

      doc.field1 = 123
      doc.field1.should == 123
      doc.valid?.should == false
      doc.errors.full_messages.first.should == "Field1 should be a point"

      doc.field1 = {:x => 123, :y => 456}
      doc.field1.should == Point.new(123, 456)
      doc.valid?.should == true

      doc.save
      SimpleDocument.first.field1.should == Point.new(123, 456)
    end
  end

  context 'when coming from the database with a cast that cannot be perfomred' do
    let(:type) { nil }
    it 'does not type check/cast' do
      doc.field1 = '1'
      doc.save
      SimpleDocument.first.field1.should == '1'
      SimpleDocument.field :field1, :type => Integer
      SimpleDocument.first.field1.should == '1'
    end
  end

  context 'when using Set type' do
    let(:type) { Set }

    it 'type checks and casts' do
      doc.field1 = 'invalid'
      doc.field1.should == 'invalid'
      doc.valid?.should == false

      doc.field1 = []
      doc.field1.should == Set.new
      doc.valid?.should == true

      doc.field1 = ['foo']
      doc.field1.should == Set.new(['foo'])
      doc.valid?.should == true

      doc.field1 = Set.new
      doc.field1.should == Set.new
      doc.valid?.should == true

      doc.field1 = Set.new(['foo'])
      doc.field1.should == Set.new(['foo'])
      doc.valid?.should == true
    end

    it 'reads back a set from the db' do
      doc.field1 = ['foo']
      doc.save
      doc.reload
      doc.field1.should == Set.new(['foo'])
    end
  end

  context 'when using Geo::Point type' do
    let(:type) { SimpleDocument::Geo::Point }

    it 'type checks and casts' do
      doc.field1 = 'invalid'
      doc.valid?.should == false

      doc.field1 = []
      doc.valid?.should == false

      doc.field1 = [1,2]
      doc.valid?.should == true
      doc.field1.should == type.new(1,2)

      doc.field1 = [1,2,3]
      doc.valid?.should == false

      doc.field1 = ['1.2', '-2']
      doc.valid?.should == true
      doc.field1.should == type.new(1.2,-2)
      doc.field1.inspect.should == [1.2, -2.0].inspect

      doc.field1 = ['1.2x', '-2']
      doc.valid?.should == false

      doc.field1 = [-180, -90]
      doc.valid?.should == true

      doc.field1 = [180, 90]
      doc.valid?.should == true

      doc.field1 = [181, 0]
      doc.valid?.should == false

      doc.field1 = [0, 91]
      doc.valid?.should == false

      doc.field1 = [-181, 0]
      doc.valid?.should == false

      doc.field1 = [0, -91]
      doc.valid?.should == false

      doc.field1 = {:longitude => 1, :latitude => 2}
      doc.valid?.should == true
      doc.field1.should == type.new(1, 2)

      doc.field1 = {:long => 1, :lat => 2}
      doc.valid?.should == true
      doc.field1.should == type.new(1, 2)

      doc.field1 = {:longi => 1, :lat => 2}
      doc.valid?.should == false

      doc.field1 = type.new(1,2)
      doc.valid?.should == true
      doc.field1.should == type.new(1,2)
    end

    it 'reads back a set from the db' do
      doc.field1 = [1,2]
      doc.save
      doc.reload
      doc.field1.should == type.new(1,2)
    end
  end

  context 'when using Enum type' do
    let(:field_options) { { :type => SimpleDocument::Enum, :in => [:a, :b] } }

    it 'type checks' do
      doc.field1 = :invalid
      doc.valid?.should == false

      doc.field1 = 'a'
      doc.valid?.should == true

      doc.field1 = :a
      doc.valid?.should == true
    end

    it 'provides additional methods' do
      doc.field1 = :a
      doc.a?.should == true
      doc.b?.should == false
      doc.save
      SimpleDocument.a.count.should == 1
      SimpleDocument.b.count.should == 0

      doc.field1 = :b
      doc.a?.should == false
      doc.b?.should == true
      doc.save
      SimpleDocument.a.count.should == 0
      SimpleDocument.b.count.should == 1
    end

    context 'when using a prefix/suffix' do
      context 'with custom names' do
        let(:field_options) { { :type => SimpleDocument::Enum, :in => [:a, :b], :prefix => :p, :suffix => :s } }

        it 'names the methods properly' do
          doc.field1 = :a
          doc.p_a_s?.should == true
          doc.p_b_s?.should == false
          doc.save
          SimpleDocument.p_a_s.count.should == 1
          SimpleDocument.p_b_s.count.should == 0
        end
      end

      context 'with default prefix' do
        let(:field_options) { { :type => SimpleDocument::Enum, :in => [:a, :b], :prefix => true } }

        it 'names the methods properly' do
          doc.field1 = :a
          doc.field1_a?.should == true
          doc.field1_b?.should == false
          doc.save
          SimpleDocument.field1_a.count.should == 1
          SimpleDocument.field1_b.count.should == 0
        end
      end

      context 'with default suffix' do
        let(:field_options) { { :type => SimpleDocument::Enum, :in => [:a, :b], :suffix => true } }

        it 'names the methods properly' do
          doc.field1 = :a
          doc.a_field1?.should == true
          doc.b_field1?.should == false
          doc.save
          SimpleDocument.a_field1.count.should == 1
          SimpleDocument.b_field1.count.should == 0
        end
      end
    end

    context 'when not specifying :in properly' do
      it 'fails' do
        expect { SimpleDocument.field :field2, :type => SimpleDocument::Enum }
          .to raise_error(/provide.*:in/)
        expect { SimpleDocument.field :field2, :type => SimpleDocument::Enum, :in => [] }
          .to raise_error(/provide.*:in/)
        expect { SimpleDocument.field :field2, :type => SimpleDocument::Enum, :in => [123] }
          .to raise_error(/symbol values/)
      end
    end

    context 'when specifying overlapping values' do
      it 'fails' do
        expect { SimpleDocument.field :field2, :type => SimpleDocument::Enum, :in => [:a] }
          .to raise_error(/already taken/)
      end
    end
  end

  context 'when using the Array literal shortcut' do
    let(:type) { [Date] }
    it 'uses a TypedArray' do
      expect(SimpleDocument.fields[:field1][:type]).to be <= NoBrainer::TypedArray
    end
  end

  context 'when using the Array.of shortcut' do
    let(:type) { SimpleDocument::Array.of(Date) }
    it 'uses a TypedArray' do
      expect(SimpleDocument.fields[:field1][:type]).to be <= NoBrainer::TypedArray
    end
  end

  context 'when using a TypedArray' do
    let(:type) { NoBrainer::TypedArray.of(Date) }

    it 'type checks and casts array elements' do
      date_strs = %w(2020-09-21 2020-09-22 2020-09-23)
      dates = date_strs.map { |s|  Date.parse(s) }

      doc.field1 = dates
      doc.field1.should == dates
      doc.valid?.should == true

      doc.field1 = date_strs
      doc.field1.should == dates
      doc.valid?.should == true

      doc.field1 = ["2014-06-26T15:34:12-02:00"]
      doc.field1.should == ["2014-06-26T15:34:12-02:00"]
      doc.valid?.should == false

      doc.field1 = dates
      doc.save
      doc.reload
      doc.field1.should == dates

      SimpleDocument.where(:field1 => dates).count.should == 1
      SimpleDocument.where(:field1.any.eq => dates.first).count.should == 1
    end
  end

  context 'when using a TypedArray (allow_nil)' do
    let(:type) { NoBrainer::TypedArray.of(Date, allow_nil: true) }

    it 'type checks array elmeents' do
      dates = %w(2020-09-21 2020-09-22 2020-09-23).map { |s|  Date.parse(s) }

      doc.field1 = dates
      doc.valid?.should == true

      doc.field1 = dates + [nil]
      doc.valid?.should == false
    end
  end
end

describe 'types' do
  before { load_simple_document }

  it 'raises with Geo::Circle' do
    expect { SimpleDocument.field :field1, :type => NoBrainer::Geo::Circle }.to raise_error(/Cannot store circles/)
  end

  it 'raises with bad types' do
    expect { SimpleDocument.field :field1, :type => "asdasd" }.to raise_error(/type option/)
  end
end
