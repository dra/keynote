# encoding: UTF-8

require "helper"
require "fileutils"
require "slim"
require "haml"
require "haml/template"

module Keynote
  describe Inline do
    let(:presenter) { InlineUser.new(:view) }

    def clean_whitespace(str)
      str.gsub(/\s/, "")
    end

    class InlineUser < Keynote::Presenter
      extend Keynote::Inline
      inline :slim, :haml

      def simple_template
        erb
        # Here's some math: <%= 2 + 2 %>
      end

      def ivars
        @greetee = "world"
        erb
        # Hello <%= @greetee %>!
      end

      def locals_from_hash
        erb local: "H"
        # Local <%= local %>
      end

      def locals_from_binding
        local = "H"
        erb binding
        # Local <%= local %>
      end

      def method_calls
        erb
        # <%= locals_from_hash %>
        # <%= locals_from_binding %>
      end

      def error_handling
        erb
        # <% raise "UH OH" %>
      end

      def fix_indentation
        slim
        # .indented_slightly
        #   - (2..4).each do |i|
        #     ' #{i} times
      end

      def erb_escaping
        raw = erb
        # <%= "<script>alert(1);</script>" %>
        escaped = erb
        # <%= "<script>alert(1);</script>".html_safe %>
        raw + escaped
      end

      def slim_escaping
        raw = slim
        # = "<script>alert(1);</script>"
        escaped = slim
        # = "<script>alert(1);</script>".html_safe
        raw + escaped
      end

      def haml_escaping
        raw = haml
        # = "<script>alert(1);</script>"
        escaped = haml
        # = "<script>alert(1);</script>".html_safe
        raw + escaped
      end
    end

    before do
      Keynote::Inline::Cache.reset
    end

    it "should render a template" do
      presenter.simple_template.strip.must_equal "Here's some math: 4"
    end

    it "should see instance variables from the presenter" do
      presenter.ivars.strip.must_equal "Hello world!"
    end

    it "should see locals passed in as a hash" do
      presenter.locals_from_hash.strip.must_equal "Local H"
    end

    it "should see locals passed in as a binding" do
      presenter.locals_from_binding.strip.must_equal "Local H"
    end

    it "should be able to call other methods from the same object" do
      presenter.method_calls.strip.squeeze(" ").must_equal "Local H\nLocal H"
    end

    it "should handle errors relatively gracefully" do
      begin
        presenter.error_handling
      rescue => e
      end

      e.must_be_instance_of ActionView::Template::Error
      e.original_exception.must_be_instance_of RuntimeError
      e.original_exception.message.must_equal "UH OH"
    end

    it "should remove leading indentation" do
      presenter.fix_indentation.must_equal \
        "<div class=\"indented_slightly\">2 times 3 times 4 times </div>"
    end

    it "should escape HTML by default" do
      unescaped = "<script>alert(1);</script>"
      escaped   = unescaped.gsub(/</, "&lt;").gsub(/>/, "&gt;")
      escaped2  = escaped.gsub(/\//, "&#47;") # for Slim w/ Rails > 3.0 (??)

      clean_whitespace(presenter.erb_escaping).must_equal escaped + unescaped
      clean_whitespace(presenter.haml_escaping).must_equal escaped + unescaped

      [escaped + unescaped, escaped2 + unescaped].must_include \
        clean_whitespace(presenter.slim_escaping)
    end

    it "should see updates after the file is reloaded" do
      presenter.simple_template.strip.must_equal "Here's some math: 4"

      Keynote::Inline::Cache.
        any_instance.stubs(:read_template).returns("HELLO")

      presenter.simple_template.strip.must_equal "Here's some math: 4"

      FileUtils.touch __FILE__

      presenter.simple_template.must_equal "HELLO"
    end
  end
end
