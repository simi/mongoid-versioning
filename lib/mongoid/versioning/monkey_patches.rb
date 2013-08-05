default_options = Mongoid::Fields::Validators::Macro::OPTIONS
Mongoid::Fields::Validators::Macro.send(:remove_const, :OPTIONS)
Mongoid::Fields::Validators::Macro.send(:const_set, :OPTIONS, default_options + [:versioned])

module Mongoid
  module Fields
    class Standard
      # Is this field included in versioned attributes?
      #
      # @example Is the field versioned?
      #   field.versioned?
      #
      # @return [ true, false ] If the field is included in versioning.
      #
      # @since 2.1.0
      def versioned?
        @versioned ||= (options[:versioned].nil? ? true : options[:versioned])
      end
    end
  end
end

module Mongoid
  module Hierarchy
    def collect_children
      children = []
      embedded_relations.each_pair do |name, metadata|
        without_autobuild do
          child = send(name)
          Array.wrap(child).each do |doc|
            children.push(doc)
            children.concat(doc._children) unless metadata.versioned?
          end if child
        end
      end
      children
    end
  end
end

module Mongoid
  module Relations
    module Bindings
      module Embedded
        # Binding class for embeds_many relations.
        class Many < Binding
          def bind_one(doc)
            doc.parentize(base)
            binding do
              unless metadata.versioned?
                doc.do_or_do_not(metadata.inverse_setter(target), base)
              end
            end
          end
        end
      end
    end
  end
end

module Mongoid
  module Relations
    # This module defines the behaviour for setting up cascading deletes and
    # nullifies for relations, and how to delegate to the approriate strategy.
    module Cascading
      def cascade!
        cascades.each do |name|
          if !metadata || !metadata.versioned?
            if meta = relations[name]
              strategy = meta.cascade_strategy
              strategy.new(self, meta).cascade if strategy
            end
          end
        end
      end
    end
  end
end

module Mongoid
  module Relations
    module Embedded

      # Contains behaviour for executing operations in batch on embedded
      # documents.
      module Batchable
        # Pre process the batch removal.
        #
        # @api private
        #
        # @example Pre process the documents.
        #   batchable.pre_process_batch_remove(docs, :delete)
        #
        # @param [ Array<Document> ] docs The documents.
        # @param [ Symbol ] method Delete or destroy.
        #
        # @return [ Array<Hash> ] The documents as hashes.
        #
        # @since 3.0.0
        def pre_process_batch_remove(docs, method)
          docs.map do |doc|
            self.path = doc.atomic_path unless path
            execute_callback :before_remove, doc
            if !_assigning? && !metadata.versioned?
              doc.cascade!
              doc.run_before_callbacks(:destroy) if method == :destroy
            end
            target.delete_one(doc)
            _unscoped.delete_one(doc)
            unbind_one(doc)
            execute_callback :after_remove, doc
            doc.as_document
          end
        end
      end
    end
  end
end

module Mongoid
  module Relations
    module Embedded

      # This class handles the behaviour for a document that embeds many other
      # documents within in it as an array.
      class Many < Relations::Many
        class << self
          # Get the valid options allowed with this relation.
          #
          # @example Get the valid options.
          #   Relation.valid_options
          #
          # @return [ Array<Symbol> ] The valid options.
          #
          # @since 2.1.0
          def valid_options
            [
              :as, :cascade_callbacks, :cyclic, :order, :versioned, :store_as,
              :before_add, :after_add, :before_remove, :after_remove
            ]
          end
        end
      end
    end
  end
end

module Mongoid
  module Relations
    # This module contains the core macros for defining relations between
    # documents. They can be either embedded or referenced (relational).
    module Macros
      module ClassMethods
        # Adds the relation back to the parent document. This macro is
        # necessary to set the references from the child back to the parent
        # document. If a child does not define this relation calling
        # persistence methods on the child object will cause a save to fail.
        #
        # @example Define the relation.
        #
        #   class Person
        #     include Mongoid::Document
        #     embeds_many :addresses
        #   end
        #
        #   class Address
        #     include Mongoid::Document
        #     embedded_in :person
        #   end
        #
        # @param [ Symbol ] name The name of the relation.
        # @param [ Hash ] options The relation options.
        # @param [ Proc ] block Optional block for defining extensions.
        def embedded_in(name, options = {}, &block)
          if ancestors.include?(Mongoid::Versioning)
            raise Errors::VersioningNotOnRoot.new(self)
          end
          meta = characterize(name, Embedded::In, options, &block)
          self.embedded = true
          relate(name, meta)
          builder(name, meta).creator(name, meta)
          meta
        end
      end
    end
  end
end

module Mongoid
  module Relations

    # The "Grand Poobah" of information about any relation is this class. It
    # contains everything you could ever possible want to know.
    class Metadata < Hash
      # Since a lot of the information from the metadata is inferred and not
      # explicitly stored in the hash, the inspection needs to be much more
      # detailed.
      #
      # @example Inspect the metadata.
      #   metadata.inspect
      #
      # @return [ String ] Oodles of information in a nice format.
      #
      # @since 2.0.0.rc.1
      def inspect
        %Q{#<Mongoid::Relations::Metadata
  autobuild:    #{autobuilding?}
  class_name:   #{class_name}
  cyclic:       #{cyclic.inspect}
  dependent:    #{dependent.inspect}
  inverse_of:   #{inverse_of.inspect}
  key:          #{key}
  macro:        #{macro}
  name:         #{name}
  order:        #{order.inspect}
  polymorphic:  #{polymorphic?}
  relation:     #{relation}
  setter:       #{setter}
  versioned:    #{versioned?}>
  }
      end

      # Is this relation using Mongoid's internal versioning system?
      #
      # @example Is this relation versioned?
      #   metadata.versioned?
      #
      # @return [ true, false ] If the relation uses Mongoid versioning.
      #
      # @since 2.1.0
      def versioned?
        !!self[:versioned]
      end

      # Get the inverse relation candidates.
      #
      # @api private
      #
      # @example Get the inverse relation candidates.
      #   metadata.inverse_relation_candidates
      #
      # @return [ Array<Metdata> ] The candidates.
      #
      # @since 3.0.0
      def inverse_relation_candidates
        relations_metadata.select do |meta|
          next if meta.versioned? || meta.name == name
          meta.class_name == inverse_class_name
        end
      end
    end
  end
end

module Mongoid
  module Threaded
    # This module contains convenience methods for document lifecycle that
    # resides on thread locals.
    module Lifecycle
      private
      # Execute a block in loading revision mode.
      #
      # @example Execute in loading revision mode.
      #   _loading_revision do
      #     load_revision
      #   end
      #
      # @return [ Object ] The return value of the block.
      #
      # @since 2.3.4
      def _loading_revision
        Threaded.begin_execution("load_revision")
        yield
      ensure
        Threaded.exit_execution("load_revision")
      end
      module ClassMethods
        # Is the current thread in loading revision mode?
        #
        # @example Is the current thread in loading revision mode?
        #   proxy._loading_revision?
        #
        # @return [ true, false ] If the thread is loading a revision.
        #
        # @since 2.3.4
        def _loading_revision?
          Threaded.executing?("load_revision")
        end
      end
    end
  end
end

module Mongoid
  module Document
    module ClassMethods
      # Instantiate a new object, only when loaded from the database or when
      # the attributes have already been typecast.
      #
      # @example Create the document.
      #   Person.instantiate(:title => "Sir", :age => 30)
      #
      # @param [ Hash ] attrs The hash of attributes to instantiate with.
      # @param [ Integer ] criteria_instance_id The criteria id that
      #   instantiated the document.
      #
      # @return [ Document ] A new document.
      #
      # @since 1.0.0
      def instantiate(attrs = nil, criteria_instance_id = nil)
        attributes = attrs || {}
        doc = allocate
        doc.criteria_instance_id = criteria_instance_id
        doc.instance_variable_set(:@attributes, attributes)
        doc.apply_defaults
        IdentityMap.set(doc)
        yield(doc) if block_given?
        doc.run_callbacks(:find) unless doc._find_callbacks.empty?
        doc.run_callbacks(:initialize) unless doc._initialize_callbacks.empty?
        doc
      end
    end
  end
end

module Mongoid
  module Sessions
    module ClassMethods
      # Get the collection for this model from the session. Will check for an
      # overridden collection name from the store_in macro or the collection
      # with a pluralized model name.
      #
      # @example Get the model's collection.
      #   Model.collection
      #
      # @return [ Moped::Collection ] The collection.
      #
      # @since 3.0.0
      def collection
        if opts = persistence_options
          coll = mongo_session.with(opts)[opts[:collection] || collection_name]
          clear_persistence_options unless validating_with_query? || _loading_revision?
          coll
        else
          mongo_session[collection_name]
        end
      end
    end
  end
end
