require 'rouge/plugins/redcarpet'

module MarkdownRenderable
  extend ActiveSupport::Concern

  class CustomRenderer < Redcarpet::Render::HTML
    def block_code(code, language)
      language ||= 'text'
      formatter = Rouge::Formatters::HTMLPygments.new(
        Rouge::Formatters::HTML.new
      )
      lexer = Rouge::Lexer.find_fancy(language, code) || Rouge::Lexers::PlainText.new
      formatter.format(lexer.lex(code))
    end

    def initialize(extensions = {})
      super(extensions.merge(
        link_attributes: { target: '_blank', rel: 'noopener noreferrer' },
        fenced_code_blocks: true,
        with_toc_data: true,
        hard_wrap: true,
        prettify: true
      ))
    end
  end

  class_methods do
    def markdown
      @markdown ||= Redcarpet::Markdown.new(
        CustomRenderer.new,
        autolink: true,
        tables: true,
        fenced_code_blocks: true,
        strikethrough: true,
        superscript: true,
        underline: true,
        highlight: true,
        quote: true,
        footnotes: true,
        space_after_headers: true,
        disable_indented_code_blocks: false
      )
    end
  end

  def markdown_to_html(text)
    self.class.markdown.render(text.to_s)
  end
end
