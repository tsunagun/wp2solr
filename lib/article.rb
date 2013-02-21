# coding: UTF-8

# Wikipediaの記事クラス
class Article
  attr_accessor :title, :redirect_from, :namespace, :page_id, :revision_id, :timestamp, :text, :categories
  def initialize
    @title = ""
    @text = ""
    @redirect_from = Array.new
    @categories = Array.new
  end

end
