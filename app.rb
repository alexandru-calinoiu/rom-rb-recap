#!/usr/bin/env ruby

require 'bundler/setup'
require 'rom-sql'
require 'rom-repository'

require 'dry-types'
require 'dry-struct'

module Relations
  class Articles < ROM::Relation[:sql]
    schema(:articles) do
      attribute :id, Types::Serial
      attribute :title, Types::String
      attribute :published, Types::Bool

      associations do
        has_many :categories, through: :articles_categories
      end
    end

    def by_id(id)
      where(id: id)
    end

    def published
      where(published: true)
    end
  end

  class Categories < ROM::Relation[:sql]
    schema(:categories) do
      attribute :id, Types::Serial
      attribute :name, Types::String
    end
  end

  class ArticlesCategories < ROM::Relation[:sql]
    schema(:articles_categories) do
      attribute :id, Types::Serial

      attribute :article_id, Types::ForeignKey(:articles)
      attribute :category_id, Types::ForeignKey(:categories)

      associations do
        belongs_to :articles
        belongs_to :categories
      end
    end
  end
end

module Types
  include Dry::Types.module
end

class Category < Dry::Struct::Value
  attribute :id, Types::Strict::Int
  attribute :name, Types::Strict::String
end

class Article < Dry::Struct::Value
  attribute :id, Types::Strict::Int
  attribute :title, Types::Strict::String
  attribute :published, Types::Strict::Bool

  attribute :categories, Types::Strict::Array.member(Category)
end

module Repositories
  class Articles < ROM::Repository[:articles]
    relations :categories

    commands :create, :update, :by_id

    def [](id)
      aggregate(:categories)
        .by_id(id)
        .as(Article)
        .one!
    end

    def published
      aggregate(:categories)
        .published
        .as(Article)
        .to_a
    end
  end
end
