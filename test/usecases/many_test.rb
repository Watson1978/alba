require_relative '../test_helper'

class ManyTest < MiniTest::Test
  class SerializerWithKey
    include Alba::Serializer

    set key: :foo
  end

  class User
    attr_reader :id, :created_at, :updated_at
    attr_accessor :articles

    def initialize(id)
      @id = id
      @created_at = Time.now
      @updated_at = Time.now
      @articles = []
    end
  end

  class Article
    attr_accessor :id, :title, :body

    def initialize(id, title, body)
      @id = id
      @title = title
      @body = body
    end
  end

  class ArticleResource
    include Alba::Resource

    attributes :title
  end

  class UserResource1
    include Alba::Resource

    attributes :id

    many :articles, resource: ArticleResource
  end

  def test_it_returns_correct_json_with_resource_option
    user = User.new(1)
    article1 = Article.new(1, 'Hello World!', 'Hello World!!!')
    user.articles << article1
    article2 = Article.new(2, 'Super nice', 'Really nice!')
    user.articles << article2
    assert_equal(
      '{"id":1,"articles":[{"title":"Hello World!"},{"title":"Super nice"}]}',
      UserResource1.new(user).serialize
    )
  end

  class UserResource2
    include Alba::Resource

    attributes :id

    many :articles do
      attributes :title, :body
    end
  end

  def test_it_returns_correct_json_with_block
    user = User.new(1)
    article1 = Article.new(1, 'Hello World!', 'Hello World!!!')
    user.articles << article1
    article2 = Article.new(2, 'Super nice', 'Really nice!')
    user.articles << article2
    assert_equal(
      '{"id":1,"articles":[{"title":"Hello World!","body":"Hello World!!!"},{"title":"Super nice","body":"Really nice!"}]}',
      UserResource2.new(user).serialize
    )
  end

  class UserResource3
    include Alba::Resource

    attributes :id

    many :articles, key: 'posts', resource: ArticleResource
  end

  def test_it_returns_correct_json_with_given_key
    user = User.new(1)
    article1 = Article.new(1, 'Hello World!', 'Hello World!!!')
    user.articles << article1
    article2 = Article.new(2, 'Super nice', 'Really nice!')
    user.articles << article2
    assert_equal(
      '{"id":1,"posts":[{"title":"Hello World!"},{"title":"Super nice"}]}',
      UserResource3.new(user).serialize
    )
  end

  class UserResource4
    include Alba::Resource

    attributes :id

    many :articles,
         proc { |articles| articles.select { |a| a.id.even? } },
         resource: ArticleResource
  end

  def test_it_returns_correct_json_with_given_condition
    user = User.new(1)
    article1 = Article.new(1, 'Hello World!', 'Hello World!!!')
    user.articles << article1
    article2 = Article.new(2, 'Super nice', 'Really nice!')
    user.articles << article2
    assert_equal(
      '{"id":1,"articles":[{"title":"Super nice"}]}',
      UserResource4.new(user).serialize
    )
  end

  def test_it_returns_json_with_null_when_articles_do_not_exist_with_resource_option
    user = User.new(1)
    user.articles = nil
    assert_equal(
      '{"id":1,"articles":null}',
      UserResource1.new(user).serialize
    )
  end

  def test_it_returns_json_with_null_when_articles_do_not_exist_with_block
    user = User.new(1)
    user.articles = nil
    assert_equal(
      '{"id":1,"articles":null}',
      UserResource2.new(user).serialize
    )
  end
end
