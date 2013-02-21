# coding: UTF-8
# Saxを利用してXMLファイルから値を抽出するスクリプト
require 'nokogiri'
require 'sanitize'
require 'timeout'
require 'rsolr'
require './lib/wiki_parser'
require './lib/article'

# WikipediaのXMLダンプを，以下のように処理する
#   * <page>が来たら，tmp_articleを作る
#   * リビジョンIDやネームスペース，記事IDなどをtmp_articleに入れる
#   * </page>が来たら，tmp_articleをsolrにaddする
#   * addしたらcountを1増やす
#   * addを100000回行うたびに，solrのcommitを行う
#   * solrのoptimizeは行っていない．必要に応じて本コードに足すか，後で行うか
class WikiSax < Nokogiri::XML::SAX::Document
  def initialize
    @mode = Array.new
    @tmp_article = Article.new
    @solr = RSolr.connect({:url => 'http://localhost:8983/solr/wikipedia'})
    @count = 0
    @pages = load_pages
    @redirects = load_redirects
  end

  def load_pages
    filename = "./src/20130125/jawiki-latest-page.sql"

    pages = Hash.new
    open(filename).each do |line|
      next unless line[0...30] =~ /INSERT INTO `page` VALUES/
      rows = line.gsub(/INSERT INTO `page` VALUES \(/, '').gsub(/\);$/, '').split("),(")
      rows.each do |row|
        id = row.slice!(/^[0-9]*,/).chomp(",")
        namespace = row.slice!(/^(-)?[0-9]*,/).chomp(",")
        title = row.gsub(/^'/, '').chomp("'").split("','").first
        pages[id] = title
      end
    end
    return pages
  end

  def load_redirects
    filename = "./src/20130125/jawiki-latest-redirect.sql"

    redirects = Hash.new{|hash,key| hash[key] = Array.new}
    open(filename).each do |line|
      next unless line[0...30] =~ /INSERT INTO `redirect` VALUES/
      rows = line.gsub(/INSERT INTO `redirect` VALUES \(/, '').gsub(/\);$/, '').split("),(")
      rows.each do |row|
        from = row.slice!(/^[0-9]*,/).chomp(",")
        namespace = row.slice!(/^(-)?[0-9]*,/).chomp(",")
        to = row.gsub(/^'/, '').chomp("'").split("','").first
        title = @pages[from]
        redirects[to] << title unless title.nil?
      end
    end
    return redirects
  end


  def start_element name, attrs = []
    @tmp_article = Article.new if name == "page"
    @mode << name.to_sym
  end

  # </page>
  #   1つの<page>セクションが終了したら，solrへのaddとcommitを行う
  # </text>
  #   1つの<text>セクションが終了したら，Wiki記法のテキストをプレーンテキストに変換する
  def end_element name
    case name
    when "page"
      add_document
      commit_documents
    when "text"
      parse_text(:plain)
    end
    @mode.pop
  end

  def characters string
    case @mode.last
    when :title
      @tmp_article.title += string if @mode.last(2) == [:page, :title]
    when :ns
      @tmp_article.namespace = string if @mode.last(2) == [:page, :ns]
    when :id
      if @mode.last(2) == [:page, :id]
        @tmp_article.page_id = string
      elsif @mode.last(2) == [:revision, :id]
        @tmp_article.revision_id = string
      end
    when :timestamp
      @tmp_article.timestamp = string if @mode.last(2) == [:revision, :timestamp]
    when :text
      @tmp_article.text += string if @mode.last(2) == [:revision, :text]
    end
  end

  def start_document
    p "Started: #{Time.now}"
  end

  def end_document
    add_document
    @solr.commit
    @solr.optimize
    p "Finished: #{Time.now}"
  end

  def add_document
    return if redirect?(@tmp_article)
    @tmp_article.redirect_from = @redirects[@tmp_article.title] || Array.new
    begin
      timeout(60) do
        document = {
          :id => @tmp_article.page_id,
          :title => @tmp_article.title,
          :redirect_from => @tmp_article.redirect_from,
          :namespace => @tmp_article.namespace,
          :text => @tmp_article.text,
          :last_modified => @tmp_article.timestamp,
          :category => @tmp_article.categories
        }
        if document.each_value.include?("")
          p "ERROR: LackValue #{document[:id]}: #{document[:title]}"
        else
          @solr.add(document)
          @count += 1
          p "SUCCESS: AddDocument: #{document[:id]}: #{document[:title]}"
        end
      end
    rescue Timeout::Error
      p "ERROR: Timeout::Add：#{@tmp_article.page_id}: #{@tmp_article.title}"
    end
  end

  def commit_documents
    if @count % 100000 == 0
      @solr.commit
    end
  end

  # Wiki記法のテキストをパースして
  #   * @tmp_articleのテキストをタグ無しのプレーンテキストにする
  #   * @tmp_articleにカテゴリを与える
  # Sanitize.cleanを行わなければ，@tmp_articleのテキストをHTML文書にしておくことも可能
  def parse_text(mode=:plain)
    begin
      timeout(60) do
        parser = WikiParser.new({:data => @tmp_article.text, :noedit => true})
        @tmp_article.categories = parser.categories
        tmp_text = parser.to_html
        tmp_text = Sanitize.clean(tmp_text) if mode == :plain
        @tmp_article.text = tmp_text
      end
    rescue Timeout::Error
      p "ERROR: Timeout::WikiCloth #{@tmp_article.page_id}: #{@tmp_article.title}"
    rescue
      p "ERROR: UnknownError::WikiCloth #{@tmp_article.page_id}: #{@tmp_article.title}"
    end
  end

  def redirect?(article)
    @redirects.each do |key, values|
      values.each do |redirect_from|
        return true if article.title == redirect_from
      end
    end
    return false
  end

end
