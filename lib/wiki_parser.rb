# coding: UTF-8

require 'wikicloth'

# WikiClothパーサのカスタマイズ
# 外部リンク
#   書式：
#     url
#     [url text]
#   例：
#     http://mdlab.slis.tsukuba.ac.jp
#     [http://mdlab.slis.tsukuba.ac.jp 杉本永森研Webページ]
#   挙動：外部リンクを文字列に置き換える
#     textが指定されていない場合，http://mdlab.slis.tsukuba.ac.jp → http://mdlab.slis.tsukuba.ac.jp
#     textが指定されている場合，[http://mdlab.slis.tsukuba.ac.jp 杉本永森研Webページ] → 杉本永森研Webページ
# 内部リンク
#   書式：
#     [[page_title(|text)]]
#   例：
#     [[Paper]]
#     [[Paper|論文一覧]]
#   挙動：
#     textが指定されていない場合，[[Paper]] → Paper
#     textが指定されている場合，[[Paper|論文一覧]] → 論文一覧
class WikiParser < WikiCloth::Parser
  external_link do |url,text|
    text.nil? ? url : text
  end

  link_for do |page,text|
    text.nil? ? page : text
  end
end
