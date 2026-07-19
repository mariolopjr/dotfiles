;; extends

;; render rustdoc markdown in doc comments so intra-doc links like [`parse`]
;; conceal to their link text, conceallevel lives in after/ftplugin/rust.lua
((line_comment (doc_comment) @injection.content)
  (#set! injection.language "markdown_inline"))

((block_comment (doc_comment) @injection.content)
  (#set! injection.language "markdown_inline"))
