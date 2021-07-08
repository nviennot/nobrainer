require 'spec_helper'

describe 'NoBrainer index' do
  before { load_simple_document }
  before { NoBrainer.drop! }
  after  { NoBrainer.drop! }

  context 'when creating/removing indexes' do
    it 'keeps indexes in sync' do
      SimpleDocument.index :field1
      NoBrainer.run(SimpleDocument.rql_table.index_list).should =~ []
      NoBrainer.sync_indexes
      NoBrainer.run(SimpleDocument.rql_table.index_list).should =~ ['field1']
      SimpleDocument.index :field2
      NoBrainer.sync_indexes
      NoBrainer.run(SimpleDocument.rql_table.index_list).should =~ ['field1', 'field2']
      SimpleDocument.remove_index :field1
      NoBrainer.sync_indexes
      NoBrainer.run(SimpleDocument.rql_table.index_list).should =~ ['field2']
      SimpleDocument.remove_index :field2
      NoBrainer.sync_indexes
      NoBrainer.run(SimpleDocument.rql_table.index_list).should =~ []
    end
  end

  context 'when updating indexes' do
    it 'keeps indexes in sync' do
      SimpleDocument.create(:field1 => 1, :field2 => 2)

      SimpleDocument.index :idx, ->(doc){ doc['field1'] }
      NoBrainer.sync_indexes

      SimpleDocument.where(:idx => 1).count.should == 1
      SimpleDocument.where(:idx => 2).count.should == 0

      SimpleDocument.index :idx, ->(doc){ doc['field2'] }
      NoBrainer.sync_indexes

      SimpleDocument.where(:idx => 1).count.should == 0
      SimpleDocument.where(:idx => 2).count.should == 1

      SimpleDocument.index :idx, ->(doc){ doc['field2'] }
      NoBrainer.sync_indexes
    end

    def synchronizer
      NoBrainer::Document::Index::Synchronizer.new(NoBrainer::Document.all)
    end

    def migration_plan
      synchronizer.generate_plan.map { |op| [op.index.name, op.op] }
    end

    it 'keeps indexes in sync efficiently' do
      SimpleDocument.index :idx
      migration_plan.should == [[:idx, :create]]
      NoBrainer.sync_indexes
      migration_plan.should == []

      SimpleDocument.index :idx, ->(doc){ doc['idx'] }
      migration_plan.should == []
      NoBrainer.sync_indexes
      migration_plan.should == []

      SimpleDocument.index :idx, ->(doc){ doc['field1'] }
      migration_plan.should == [[:idx, :update]]
      NoBrainer.sync_indexes
      migration_plan.should == []

      SimpleDocument.index :idx, ->(doc){ doc['field1'] }, :multi => true
      migration_plan.should == [[:idx, :update]]
      NoBrainer.sync_indexes
      migration_plan.should == []
    end

    context 'when switching tables and dbs' do
      before do
        SimpleDocument.table_config :name => 'some_table'
        NoBrainer.run_with(:db => 'some_test_db') { NoBrainer.drop! }
      end

      it 'keeps indexes in sync' do
        SimpleDocument.index :idx

        NoBrainer.run_with(:db => 'some_test_db') do
          migration_plan.should == [[:idx, :create]]
          NoBrainer.sync_indexes
          migration_plan.should == []

          NoBrainer::Document::Index::MetaStore.first.table_name.should == 'some_table'
        end

        migration_plan.should_not == []
          NoBrainer::Document::Index::MetaStore.first.should == nil
      end
    end

    context 'with external indexes' do
      before do
        SimpleDocument.first
      end

      it 'keeps indexes in sync' do
        SimpleDocument.index :idx, :external => true
        migration_plan.should == []

        SimpleDocument.index :idx, :external => false
        migration_plan.should == [[:idx, :create]]
        NoBrainer.sync_indexes

        SimpleDocument.index :idx, ->(doc){ doc['field1'] }, :external => true
        migration_plan.should == []
        NoBrainer.sync_indexes
      end
    end
  end

  context 'when querying the primary key' do
    let!(:doc1) { SimpleDocument.create(:field1 => 'hello') }

    it 'uses the primary key index' do
      SimpleDocument.where(SimpleDocument.pk_name => doc1.pk_value).where_indexed?.should == true
      SimpleDocument.where(SimpleDocument.pk_name => doc1.pk_value).count.should == 1
    end
  end

  context 'when indexing a field on a field declaration' do
    before do
      SimpleDocument.field :field4, :index => true
      NoBrainer.sync_indexes
    end

    let!(:doc1) { SimpleDocument.create(:field4 => 'hello') }
    let!(:doc2) { SimpleDocument.create(:field4 => 'ohai') }

    it 'uses the index' do
      SimpleDocument.where(:field4 => 'ohai').where_indexed?.should == true
      SimpleDocument.where(:field4 => 'ohai').count.should == 1
    end
  end

  context 'when indexing a field on a belongs_to' do
    before do
      load_blog_models
      Comment.belongs_to :post, :index => true
      NoBrainer.sync_indexes
    end

    let!(:post)    { Post.create }
    let!(:comment) { Comment.create(:post => post) }

    it 'uses the index' do
      post.comments.where_indexed?.should == true
      post.comments.count.should == 1
    end
  end

  context 'when indexing a field normally, but without creating the index' do
    before { SimpleDocument.index :field1 }
    before { NoBrainer.logger.level = Logger::FATAL }

    it 'raises' do
      SimpleDocument.where(:field1 => 'ohai').where_indexed?.should == true
      expect { SimpleDocument.where(:field1 => 'ohai').count }.to raise_error(
        NoBrainer::Error::MissingIndex, /Please run.*to create the index `field1` in the table `#{NoBrainer.connection.parsed_uri[:db]}\.simple_documents`/)
    end
  end

  context 'when indexing a field normally' do
    before do
      SimpleDocument.index :field1
      NoBrainer.sync_indexes
    end

    let!(:doc1) { SimpleDocument.create(:field1 => 'hello', :field2 => 'yay') }
    let!(:doc2) { SimpleDocument.create(:field1 => 'world', :field2 => 'yay') }
    let!(:doc3) { SimpleDocument.create(:field1 => 'ohai',  :field2 => 'sup') }
    let!(:doc4) { SimpleDocument.create(:field1 => 'ohai',  :field2 => 'ola') }

    it 'uses the index' do
      SimpleDocument.where(:field1 => 'ohai').where_indexed?.should == true
      SimpleDocument.where(:field1 => 'ohai').count.should == 2
      SimpleDocument.where(:field2 => 'yay').where_indexed?.should == false
      SimpleDocument.where(:field2 => 'yay').count.should == 2
    end

    context 'when using a without_index where' do
      it 'does not use an index' do
        SimpleDocument.without_index.where(:field1 => 'ohai').where_indexed?.should == false
        SimpleDocument.without_index.where(:field1 => 'ohai').count.should == 2
        SimpleDocument.where(:field1 => 'ohai').without_index.where_indexed?.should == false
        SimpleDocument.where(:field1 => 'ohai').without_index.count.should == 2
      end
    end

    context 'when using multiple where' do
      it 'uses the index' do
        SimpleDocument.where(:field1 => 'ohai', :field2 => 'sup').where_indexed?.should == true
        SimpleDocument.where(:field1 => 'ohai', :field2 => 'sup').count.should == 1
      end
    end

    context 'when using in' do
      it 'uses the index' do
        SimpleDocument.where(:field1.in => ['hello', 'world']).where_indexed?.should == true
        SimpleDocument.where(:field1.in => ['hello', 'world']).count.should == 2
        SimpleDocument.where(:field1.in => []).count.should == 0
      end
    end
  end

  context 'when indexing two fields' do
    before do
      SimpleDocument.index :field1
      SimpleDocument.index :field2
      NoBrainer.sync_indexes
    end

    let!(:doc1) { SimpleDocument.create(:field1 => 'hello', :field2 => 'yay') }
    let!(:doc2) { SimpleDocument.create(:field1 => 'ohai',  :field2 => 'yay') }

    it 'uses the first declared index' do
      SimpleDocument.where(:field2 => 'yay', :field1 => 'ohai').used_index.should == :field1
      SimpleDocument.where(:field2 => 'yay', :field1 => 'ohai').count.should == 1
    end

    it 'allow to specify the index to be used' do
      SimpleDocument.with_index(:field1).where(:field2 => 'yay', :field1 => 'ohai').used_index.should == :field1
      SimpleDocument.with_index(:field1).where(:field2 => 'yay', :field1 => 'ohai').count.should == 1
      SimpleDocument.with_index(:field2).where(:field2 => 'yay', :field1 => 'ohai').used_index.should == :field2
      SimpleDocument.with_index(:field2).where(:field2 => 'yay', :field1 => 'ohai').count.should == 1

      expect { SimpleDocument.with_index(:field3).where(:field2 => 'yay', :field1 => 'ohai').count }
        .to raise_error(NoBrainer::Error::CannotUseIndex, "Cannot use index field3")
      expect { SimpleDocument.with_index(:field1).where(:field2 => 'yay').count }
        .to raise_error(NoBrainer::Error::CannotUseIndex, "Cannot use index field1")
    end

    it 'allow to specify some index to be used' do
      SimpleDocument.with_index.where(:field1 => 'yay').used_index.should == :field1
      SimpleDocument.with_index.where(:field2 => 'yay').used_index.should == :field2

      # The implicit ordering on the indexed pk does not count.
      expect { SimpleDocument.with_index.where(:field3 => 'yay').count }
        .to raise_error(NoBrainer::Error::CannotUseIndex, "Cannot use any indexes")
    end
  end

  context 'when using a multi single field index' do
    before do
      SimpleDocument.field :field1, :index => {:multi => true}
      NoBrainer.sync_indexes
    end

    let!(:doc1) { SimpleDocument.create(:field1 => ['hello', 'ohai']) }
    let!(:doc2) { SimpleDocument.create(:field1 => ['hello', 'world']) }
    let!(:doc3) { SimpleDocument.create(:field1 => ['this', 'is', 'fun']) }

    it 'uses the index' do
      SimpleDocument.where(:field1.any => 'hello').count.should == 2
      SimpleDocument.where(:field1.any => 'is').count.should == 1
      SimpleDocument.where(:field1.any => ['hello', 'ohai']).count.should == 0
    end

    it 'reflects' do
      SimpleDocument.indexes[:field1].human_name.should == "index SimpleDocument.field1"
    end
  end

  context 'when using a multi single field index (no hash)' do
    before do
      SimpleDocument.field :field1, :index => :multi
      NoBrainer.sync_indexes
    end

    let!(:doc1) { SimpleDocument.create(:field1 => ['hello', 'ohai']) }
    let!(:doc2) { SimpleDocument.create(:field1 => ['hello', 'world']) }
    let!(:doc3) { SimpleDocument.create(:field1 => ['this', 'is', 'fun']) }

    it 'uses the index' do
      SimpleDocument.where(:field1.any => 'hello').count.should == 2
      SimpleDocument.where(:field1.any => 'is').count.should == 1
      SimpleDocument.where(:field1.any => ['hello', 'ohai']).count.should == 0
    end
  end

  context 'when indexing a field with a lambda' do
    before do
      SimpleDocument.index :field12, ->(doc){ doc['field1'] + "_" + doc['field2'] }
      NoBrainer.sync_indexes
    end

    let!(:doc1) { SimpleDocument.create(:field1 => 'hello', :field2 => 'world') }
    let!(:doc2) { SimpleDocument.create(:field1 => 'ohai',  :field2 => 'yay') }

    it 'uses the index' do
      SimpleDocument.where(:field12 => 'hello_world').where_indexed?.should == true
      SimpleDocument.where(:field12 => 'hello_world').count.should == 1
    end

    it 'does not allow to use a field with the same name as an index' do
      SimpleDocument.index :index_name, ->(doc){}
      expect { SimpleDocument.field :index_name }
        .to raise_error(/index_name.*already declared/)
    end

    it 'does not allow to use an index with the same name' do
      SimpleDocument.field :field_name
      expect { SimpleDocument.index :field_name, ->(doc){} }
        .to raise_error(/field_name.*is already declared/)
    end
  end

  context 'when indexing a lambda with the multi flag' do
    before do
      SimpleDocument.index :field12, ->(doc){ [doc['field1'], doc['field2']] }, :multi => true
      NoBrainer.sync_indexes
    end

    let!(:doc1) { SimpleDocument.create(:field1 => 'hello', :field2 => 'ohai') }
    let!(:doc2) { SimpleDocument.create(:field1 => 'ohai',  :field2 => 'this') }
    let!(:doc3) { SimpleDocument.create(:field1 => 'hello', :field2 => 'there') }

    it 'uses the index' do
      SimpleDocument.where(:field12.any => 'hello').count.should == 2
      SimpleDocument.where(:field12.any => 'ohai').count.should == 2
      SimpleDocument.where(:field12.any => 'this').count.should == 1
      SimpleDocument.where(:field12.any => ['hello', 'ohai']).count.should == 0
    end
  end

  context 'when indexing a compound field' do
    before do
      SimpleDocument.index :field12, [:field1, :field2]
      NoBrainer.sync_indexes
    end

    let!(:doc1) { SimpleDocument.create(:field1 => 'hello', :field2 => 'world') }
    let!(:doc2) { SimpleDocument.create(:field1 => 'ohai',  :field2 => 'yay') }
    let!(:doc3) { SimpleDocument.create(:field1 => 'hello', :field2 => 'springfield') }

    it 'uses the index' do
      SimpleDocument.where(:field12 => ['hello', 'world']).where_indexed?.should == true
      SimpleDocument.where(:field12 => ['hello', 'world']).count.should == 1
    end

    it 'uses an index when possible' do
      SimpleDocument.where(:field1 => 'ohai', :field2 => 'yay').used_index.should == :field12
      SimpleDocument.where(:field1 => 'ohai', :field2 => 'yay').count.should == 1
    end

    it 'uses a partial index when possible' do
      SimpleDocument.where(:field1 => 'hello').used_index.should == :field12
      SimpleDocument.where(:field1 => 'hello').count.should == 2
    end

    it 'uses a partial index with range' do
      SimpleDocument.where(:field1 => 'hello', :field2 => ('t'..'z')).used_index.should == :field12
      SimpleDocument.where(:field1 => 'hello', :field2 => ('t'..'z')).count.should == 1

      SimpleDocument.where(:field1 => 'hello', :field2 => ('s'..'x')).used_index.should == :field12
      SimpleDocument.where(:field1 => 'hello', :field2 => ('s'..'x')).count.should == 2
    end

    it 'does not allow to use a field with the same name as an index' do
      SimpleDocument.index :index_name, [:field1, :field2]
      expect { SimpleDocument.field :index_name }
        .to raise_error(/index_name.*is already declared/)
    end

    it 'does not allow to use an index with the same name' do
      SimpleDocument.field :field_name
      expect { SimpleDocument.index :field_name, [:field1, :field2] }
        .to raise_error(/field_name.*is already declared/)
    end
  end

  context 'when indexing a compound field with an implicit index name' do
    before do
      SimpleDocument.index [:field1, :field2]
      NoBrainer.sync_indexes
    end

    let!(:doc1) { SimpleDocument.create(:field1 => 'hello', :field2 => 'world') }
    let!(:doc2) { SimpleDocument.create(:field1 => 'ohai',  :field2 => 'yay') }

    it 'uses the index' do
      SimpleDocument.where(:field1_field2 => ['hello', 'world']).where_indexed?.should == true
      SimpleDocument.where(:field1_field2 => ['hello', 'world']).count.should == 1
    end

    it 'uses an index when possible' do
      SimpleDocument.where(:field1 => 'ohai', :field2 => 'yay').used_index.should == :field1_field2
      SimpleDocument.where(:field1 => 'ohai', :field2 => 'yay').count.should == 1
    end
  end

  context 'with a scope' do
    before do
      SimpleDocument.class_eval do
        SimpleDocument.index :field1
        default_scope { where(:field1 => 123) }
      end
    end

    it 'reports the index to be used' do
      SimpleDocument.where_indexed?.should == true
      SimpleDocument.used_index.should == :field1
    end
  end

  context 'with bad arguments' do
    it 'raises' do
      expect { SimpleDocument.index :name, 123 }.to raise_error(/argument must be/)
      expect { SimpleDocument.index :or }.to raise_error(/reserved/)
      expect { SimpleDocument.index :compount, [:field1] }.to raise_error(/more fields/)
    end
  end

  context 'when removing an index' do
    it 'removes the index' do
      SimpleDocument.field :field1, :index => true
      SimpleDocument.where(:field1 => 123).where_indexed?.should == true
      SimpleDocument.field :field1, :index => false
      SimpleDocument.where(:field1 => 123).where_indexed?.should == false
    end
  end
end
