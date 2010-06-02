module ViewBuilders
	module Helpers
		module ListHtmlHelper

			def list_html(*args, &proc)
				options = args.extract_options!

				builder_class = options[:builder] || ViewBuilders::Bass.default_list_builder
				builder = builder_class.new(self)
				builder.list(&proc)
			end
		end

		class VerySimpleListBuilder #:nodoc:
			def initialize(template)
				@template = template
			end

			def list(*args, &proc)
				options = args.extract_options!
				default_handler(:render_list, *([args]+[options.merge(:builder => self)]), &proc)
			end

			def header_row(*args, &proc)
				default_handler(:render_header_row, *args, &proc)
			end

			alias :header :header_row

			def header_column(*args, &proc)
				default_handler(:render_header_column, *args, &proc)
			end

			def row(*args, &proc)
				default_handler(:render_row, *args, &proc)
			end

			def column(*args, &proc)
				default_handler(:render_column, *args, &proc)
			end

			private

			def default_handler(method, *args, &proc)
				options = args.extract_options!
				content = self.send(method, block_given? ? @template.capture(options.delete(:builder), &proc) : args.first, options)
				block_given? ? @template.concat(content) : content
			end

			def render_content_tag(type, content, options)
				@template.content_tag(type, content, options)
			end

			def render_content_tag_with_forced_class(type, classname, content, options)
				options[:class] = [classname, options[:class]].reject(&:blank?).join(" ")
				render_content_tag type, content, options
			end

			def render_list(content, options)
				render_content_tag_with_forced_class(:div, 'list', content, options)
			end

			def render_header_row(content, options)
				render_content_tag_with_forced_class(:div, 'header', content, options)
			end

			def render_header_column(content, options)
				render_content_tag_with_forced_class(:div, 'header_column', content, options)
			end

			def render_row(content, options)
				render_content_tag_with_forced_class(:div, 'row', content, options)
			end

			def render_column(content, options)
				render_content_tag_with_forced_class(:div, 'column', content, options)
			end
		end

		class PuristListBuilder < VerySimpleListBuilder #:nodoc:
			private

			def render_list(content, options)
				render_content_tag(:ul, content, {:class => "list"}.merge(options))
			end

			def render_row(content, options)
				render_content_tag(:li, content, {:class => "row"}.merge(options))
			end
		end
	end

	class Bass
		cattr_accessor :default_list_builder
		self.default_list_builder = ::ViewBuilders::Helpers::PuristListBuilder
	end
end

