# Wikipediaインポート

## 概要

Wikipediaの記事をApache Solrに登録するためのスクリプト．  
XMLダンプから記事のタイトルや名前空間，本文を取得して登録する．  
Wikipediaデータの登録時に以下の処理を加える．

* Wiki記法のマークアップを除去する
* リダイレクト元ページのタイトルを，リダイレクト先ページの別タイトルとして登録する

実行時には，jawiki-latest-pages-articles.xml，jawiki-latest-page.sql，jawiki-latest-redirect.sql が必要．
main.rbや，lib/wiki_sax.rbのWikiSax#load_pagesやWikiSax#load_redirectsでファイル読み込みを行っているので，そこ見て適当なディレクトリに必要なファイルを置いておく．

## 注意

* ファイル名やSolrのURLがハードコーティング，Wiki記法のパース失敗が少なくない，テストが無いなど多数問題あり．
* あくまでSaxのサンプルコード．本気で使うなら多くの箇所でコード書き直した方がよい．
* 本文はWiki記法で書かれたテキストをHTMLに変換してから，HTMLのタグを除去している．Wiki記法のパースに失敗した場合は，Wiki記法のままでSolrに登録する．
* WikiSax#end_documentにcommitがタイムアウトする既知のエラー．適当にrescue書いておくか，エラー出たらWebインタフェースでコミットし直すか．
* とにかく時間がかかる．実行時間はMacProで1週間ほどだったはず．形態素解析ではなくbigramを使用した場合は4日ほど．
** XMLダンプをRDBに入れてから，SolrのDataImportHandlerで登録した方が早いのかも…
