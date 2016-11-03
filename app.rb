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

class Category < Dry::Struct
  attribute :id, Types::Strict::Int
  attribute :name, Types::Strict::String
end

class Article < Dry::Struct
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

config = ROM::Configuration.new(:sql, 'sqlite::memory')
config.register_relation Relations::Articles
config.register_relation Relations::Categories
config.register_relation Relations::ArticlesCategories
container = ROM.container(config)

container.gateways[:default].tap do |gateway|
  migration = gateway.migration do
    change do
      create_table :articles do
        primary_key :id
        string :title, null: false
        boolean :published, null: false, default: false
      end

      create_table :categories do
        primary_key :id
        string :name
      end

      create_table :articles_categories do
        primary_key :id
        foreign_key :article_id, :articles, null: false
        foreign_key :category_id, :categories, null: false
      end
    end
  end

  migration.apply gateway.connection, :up
end

repo = Repositories::Articles.new(container)

repo.create(title: 'Conversational rom-rb', published: true)
connection = container.gateways[:default].connection
connection.execute "INSERT INTO categories (name) VALUES ('dry-rb')"
connection.execute "INSERT INTO categories (name) VALUES ('rom-rb')"
connection.execute 'INSERT INTO articles_categories (article_id, category_id) VALUES (1, 1)'
connection.execute 'INSERT INTO articles_categories (article_id, category_id) VALUES (1, 2)'

require 'ap'

p 'Published articles'
published = repo.published
ap published.first.categories.inspect