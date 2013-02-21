require './lib/wiki_sax'
require 'nokogiri'

=begin
SAX APIを使用して，WikipediaのデータをApache Solrに登録するスクリプト．
Solrのスキーマファイルschema.xmlは以下のように設定した．
インデキシング時のトークン作成には，solr.JapaneseTokenizerFactoryによる形態素解析を利用している．
形態素解析ではなくbigramを利用する場合は，/schema/fields/field/@type の値をtext_jaからtext_cjkに変えること．


<?xml version="1.0" encoding="UTF-8" ?>

<schema name="wikipedia" version="1.5">
  <types>
    <fieldType name="int" class="solr.TrieIntField" precisionStep="0" positionIncrementGap="0"/>
    <fieldType name="float" class="solr.TrieFloatField" precisionStep="0" positionIncrementGap="0"/>
    <fieldType name="long" class="solr.TrieLongField" precisionStep="0" positionIncrementGap="0"/>
    <fieldType name="double" class="solr.TrieDoubleField" precisionStep="0" positionIncrementGap="0"/>
    <fieldType name="string"  class="solr.StrField" sortMissingLast="true" omitNorms="true"/>
    <fieldType name="tdate" class="solr.TrieDateField" omitNorms="true" precisionStep="6" positionIncrementGap="0"/>
    <fieldType name="text_cjk" class="solr.TextField" positionIncrementGap="100">
      <analyzer>
        <tokenizer class="solr.CJKTokenizerFactory"/>
      </analyzer>
    </fieldType>
    <fieldType name="text_ja" class="solr.TextField" positionIncrementGap="100">
      <analyzer>
        <tokenizer class="solr.JapaneseTokenizerFactory" mode="search" />
      </analyzer>
    </fieldType>
  </types>
  <fields>
    <field name="id" type="string" indexed="true" stored="true" required="true" />
    <field name="title" type="text_ja" indexed="true" stored="true" required="true" />
    <field name="redirect_from" type="text_ja" indexed="true" stored="true" multiValued="true" />
    <field name="namespace" type="string" indexed="true" stored="true" required="true" />
    <field name="text" type="text_ja" indexed="true" stored="true" required="true" />
    <field name="last_modified" type="tdate" indexed="true" stored="true"/>
    <field name="category" type="string" indexed="true" stored="true" multiValued="true" />
    <field name="_version_" type="long" indexed="true" stored="true"/>
  </fields>
  <uniqueKey>id</uniqueKey>
  <defaultSearchField>text</defaultSearchField>
  <solrQueryParser defaultOperator="AND"/>
</schema>
=end


file = ARGV[0] || './src/20130125/jawiki-latest-pages-articles.xml'
parser = Nokogiri::XML::SAX::Parser.new(WikiSax.new)
parser.parse_file(file)
