require_relative 'serializer'
require_relative 'one'
require_relative 'many'

module Alba
  # This module represents what should be serialized
  module Resource
    # @!parse include InstanceMethods
    # @!parse extend ClassMethods
    DSLS = {_attributes: {}, _serializer: nil, _key: nil, _transform_keys: nil}.freeze
    private_constant :DSLS

    # @private
    def self.included(base)
      super
      base.class_eval do
        # Initialize
        DSLS.each do |name, initial|
          instance_variable_set("@#{name}", initial.dup) unless instance_variable_defined?("@#{name}")
        end
      end
      base.include InstanceMethods
      base.extend ClassMethods
    end

    # Instance methods
    module InstanceMethods
      attr_reader :object, :_key, :params

      # @param object [Object] the object to be serialized
      # @param params [Hash] user-given Hash for arbitrary data
      def initialize(object, params: {})
        @object = object
        @params = params.freeze
        DSLS.each_key { |name| instance_variable_set("@#{name}", self.class.public_send(name)) }
      end

      # Get serializer with `with` argument and serialize self with it
      #
      # @param with [nil, Proc, Alba::Serializer] selializer
      # @return [String] serialized JSON string
      def serialize(with: nil)
        serializer = case with
                     when nil
                       @_serializer || empty_serializer
                     when ->(obj) { obj.is_a?(Class) && obj <= Alba::Serializer }
                       with
                     when Proc
                       inline_extended_serializer(with)
                     else
                       raise ArgumentError, 'Unexpected type for with, possible types are Class or Proc'
                     end
        serializer.new(self).serialize
      end

      # A Hash for serialization
      #
      # @return [Hash]
      def serializable_hash
        cache = Alba.cache
        cache_key = if cache.is_a?(NullCacheStore)
                      nil
                    else
                      @object.respond_to?(:cache_key_with_version) ? @object.cache_key_with_version : nil
                    end
        cache = NullCacheStore.new if cache_key.nil?
        cache.fetch(cache_key) do
          collection? ? @object.map(&converter) : converter.call(@object)
        end
      end
      alias to_hash serializable_hash

      # @return [Symbol]
      def key
        @_key || self.class.name.delete_suffix('Resource').downcase.gsub(/:{2}/, '_').to_sym
      end

      private

      # rubocop:disable Style/MethodCalledOnDoEndBlock
      def converter
        lambda do |resource|
          @_attributes.map do |key, attribute|
            [transform_key(key), fetch_attribute(resource, attribute)]
          end.to_h
        end
      end
      # rubocop:enable Style/MethodCalledOnDoEndBlock

      # Override this method to supply custom key transform method
      def transform_key(key)
        return key unless @_transform_keys

        require_relative 'key_transformer'
        KeyTransformer.transform(key, @_transform_keys)
      end

      def fetch_attribute(resource, attribute)
        case attribute
        when Symbol
          resource.public_send attribute
        when Proc
          instance_exec(resource, &attribute)
        when Alba::One, Alba::Many
          attribute.to_hash(resource, params: params)
        else
          raise ::Alba::Error, "Unsupported type of attribute: #{attribute.class}"
        end
      end

      def empty_serializer
        klass = Class.new
        klass.include Alba::Serializer
        klass
      end

      def inline_extended_serializer(with)
        klass = empty_serializer
        klass.class_eval(&with)
        klass
      end

      def collection?
        @object.is_a?(Enumerable)
      end
    end

    # Class methods
    module ClassMethods
      attr_reader(*DSLS.keys)

      # @private
      def inherited(subclass)
        super
        DSLS.each_key { |name| subclass.instance_variable_set("@#{name}", instance_variable_get("@#{name}").clone) }
      end

      # Set multiple attributes at once
      #
      # @param attrs [Array<String, Symbol>]
      def attributes(*attrs)
        attrs.each { |attr_name| @_attributes[attr_name.to_sym] = attr_name.to_sym }
      end

      # Set an attribute with the given block
      #
      # @param name [String, Symbol] key name
      # @param block [Block] the block called during serialization
      # @raise [ArgumentError] if block is absent
      def attribute(name, &block)
        raise ArgumentError, 'No block given in attribute method' unless block

        @_attributes[name.to_sym] = block
      end

      # Set One association
      #
      # @param name [String, Symbol]
      # @param condition [Proc]
      # @param resource [Class<Alba::Resource>]
      # @param key [String, Symbol] used as key when given
      # @param block [Block]
      # @see Alba::One#initialize
      def one(name, condition = nil, resource: nil, key: nil, &block)
        @_attributes[key&.to_sym || name.to_sym] = One.new(name: name, condition: condition, resource: resource, &block)
      end
      alias has_one one

      # Set Many association
      #
      # @param name [String, Symbol]
      # @param condition [Proc]
      # @param resource [Class<Alba::Resource>]
      # @param key [String, Symbol] used as key when given
      # @param block [Block]
      # @see Alba::Many#initialize
      def many(name, condition = nil, resource: nil, key: nil, &block)
        @_attributes[key&.to_sym || name.to_sym] = Many.new(name: name, condition: condition, resource: resource, &block)
      end
      alias has_many many

      # Set serializer for the resource
      #
      # @param name [Alba::Serializer]
      def serializer(name)
        @_serializer = name <= Alba::Serializer ? name : nil
      end

      # Set key
      #
      # @param key [String, Symbol]
      def key(key)
        @_key = key.to_sym
      end

      # Delete attributes
      # Use this DSL in child class to ignore certain attributes
      #
      # @param attributes [Array<String, Symbol>]
      def ignoring(*attributes)
        attributes.each do |attr_name|
          @_attributes.delete(attr_name.to_sym)
        end
      end

      # Transform keys as specified type
      #
      # @params type [String, Symbol]
      def transform_keys(type)
        @_transform_keys = type.to_sym
      end
    end
  end
end
