require_relative '../test_helper'

class TypeValidationTest < MiniTest::Test
  class User
    attr_reader :id, :name, :age, :bio, :admin, :created_at

    def initialize(id, name, age, bio = '', admin = false) # rubocop:disable Style/OptionalBooleanParameter
      @id = id
      @name = name
      @age = age
      @admin = admin
      @bio = bio
      @created_at = Time.new(2020, 10, 10)
    end
  end

  class UserResource
    include Alba::Resource

    attributes :name, id: [String, true], age: [Integer, true], bio: String, admin: [:Boolean, true], created_at: [String, ->(object) { object.strftime('%F') }]
  end

  def setup
    Alba.backend = nil

    @user = User.new(1, 'Masafumi OKURA', 32, 'Ruby dev')
  end

  def test_it_returns_correct_json_with_no_opt
    assert_equal(
      '{"name":"Masafumi OKURA","id":"1","age":32,"bio":"Ruby dev","admin":false,"created_at":"2020-10-10"}',
      UserResource.new(@user).serialize
    )
  end

  def test_it_converts_types_if_converter_is_set
    user = User.new(1, :Masafumi, '32')
    assert_equal(
      '{"name":"Masafumi","id":"1","age":32,"bio":"","admin":false,"created_at":"2020-10-10"}',
      UserResource.new(user).serialize
    )
  end

  def test_it_raises_error_when_type_conversion_fails
    user = User.new(1, 'Masafumi OKURA', Object.new)
    error = assert_raises(TypeError) { UserResource.new(user).serialize }
    assert_equal 'Attribute age is expected to be Integer but actually Object.', error.message
  end

  def test_it_raises_error_when_some_data_with_auto_conversion_is_nil
    user = User.new(1, 'Masafumi OKURA', nil)
    assert_raises(TypeError) { UserResource.new(user).serialize }
  end

  def test_it_raises_error_when_some_data_without_auto_conversion_is_nil
    user = User.new(1, 'Masafumi OKURA', 32, nil)
    error = assert_raises(TypeError) { UserResource.new(user).serialize }
    assert_equal 'Attribute bio is expected to be String but actually nil.', error.message
  end

  class UnsupportedTypeUserResource
    include Alba::Resource

    attributes name: Symbol
  end

  def test_it_raises_error_when_type_is_not_supported
    assert_raises(Alba::UnsupportedType) { UnsupportedTypeUserResource.new(@user).serialize }
  end

  class Foo
    attr_reader :number

    def initialize(number)
      @number = number
    end
  end

  class FooResource
    include Alba::Resource

    attributes number: :Number
  end

  def test_it_validates_number_type
    foo = Foo.new(42.0)
    assert_equal '{"number":42.0}', FooResource.new(foo).serialize
    foo2 = Foo.new('foo')
    assert_raises(TypeError) { FooResource.new(foo2).serialize }
  end

  class FooResourceWithAutoConversion
    include Alba::Resource

    attributes number: [:Number, true]
  end

  def test_it_provides_default_converter_for_number
    foo = Foo.new('42.0')
    assert_equal '{"number":42.0}', FooResourceWithAutoConversion.new(foo).serialize
  end

  class FooResourceWithFloat
    include Alba::Resource

    attributes number: Float
  end

  def test_it_works_with_float_type
    foo = Foo.new(42.0)
    assert_equal '{"number":42.0}', FooResourceWithFloat.new(foo).serialize
  end
end
