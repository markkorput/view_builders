module ViewBuilders
	module Helpers
		def list_html(*args, &proc)
			options = args.extract_options!

			builder_class = options.delete(:builder) || ViewBuilders::Base.default_list_builder
			builder = builder_class.new(self)
			builder.list(options, &proc)
		end

		def show_html(*args, &proc)
			options = args.extract_options!

			builder_class = options.delete(:builder) || ViewBuilders::Base.default_show_builder
			builder = builder_class.new(nil, self, options)
			builder.show(&proc)
		end

		def show_for(object, *args, &proc)
			options = args.extract_options!

			builder_class = options.delete(:builder) || ViewBuilders::Base.default_show_builder
			builder = builder_class.new(object, self, options)
			builder.show(&proc)
		end

		def crud_page_html(*args, &proc)
			options = args.extract_options!

			builder_class = options.delete(:builder) || ViewBuilders::Base.default_crud_page_builder
			builder = builder_class.new(nil, self)
			builder.crud_page(options, &proc)
		end

	end


	module Builders

		class GeneralBuilder
			def initialize(template)
				@template = template
			end

			private

			def default_handler(method, *args, &proc)
				options = args.extract_options!
				content = self.send(method, block_given? ? @template.capture(options.delete(:builder), &proc) : args.first, options)
				block_given? ? @template.concat(content) : content
			end

			def render_content_tag_with_forced_class(type, classname, content, options)
				@template.content_tag type, content, options.merge(:class => [classname, options[:class]].reject(&:blank?).join(" "))
			end
		end

		class VerySimpleListBuilder < GeneralBuilder #:nodoc:
			def list(*args, &proc)
				options = args.extract_options!
				default_handler(:render_list, *(args+[options.merge(:builder => self)]), &proc)
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
				render_content_tag_with_forced_class(:ul, 'list', content, options)
				# @template.content_tag(:ul, content, {:class => "list"}.merge(options))
			end

			def render_row(content, options)
				#@template.content_tag(:li, content, {:class => "row#{@template.cycle(' odd', '')}"}.merge(options))
				render_content_tag_with_forced_class(:li, "row#{@template.cycle(' odd', '')}", content, options)
			end

			def render_header_row(content, options)
				render_content_tag_with_forced_class(:li, 'row header', content, options)
			end
		end


		class SimpleShowBuilder < GeneralBuilder
			attr_reader :object

			def initialize(object, template, options = {})
				@object, @template, @options = object, template, options
			end

			def show(*args, &proc)
				options = args.extract_options!
				default_handler(:render_show, *(args+[options.merge(:builder => self)]), &proc)
			end

			def attribute_html(name, value, options = {})
				render_attribute(name, value, options)
			end

			def attribute(attr, options = {})
				render_attribute(
					attribute_name_content(@object, attr, options),
					attribute_value_content(@object, attr, options),
					options.merge(:attribute_name => attr.to_s)
				)
			end

			def attributes(*args)
				options = args.extract_options!
				return args.map{|arg| self.attribute(arg, options)}.join
			end

			private

			def render_show(content, options)
				render_content_tag_with_forced_class(:ul, "show#{@object ? " " + @template.dom_class(@object) : ''}", content, options)
			end

			def render_attribute(name, value, options = {})
				li_class = options.delete(:attribute_name)
				content = render_attribute_name(name, options.delete(:name_options) || {}) + render_attribute_value(value, options.delete(:value_options) || {})
				render_content_tag_with_forced_class(:li, li_class, content, options)
			end

			def render_attribute_name(content, options)
				render_content_tag_with_forced_class(:div, 'name', content, options)
			end

			def render_attribute_value(content, options)
				render_content_tag_with_forced_class(:div, 'value', content, options)
			end

			def attribute_name_content(object, attr, options = {})
				options[:name] || object.class.human_attribute_name(attr)
			end

			def attribute_value_content(object, attr, options = {})
				if (value = options[:value]).nil?
					value = object.respond_to?(attr) ? object.send(attr) : nil

					case value
						when Date, Time, DateTime:
							value = options[:date_format] ? @template.l(value, :format => options[:date_format]) : @template.l(value)
						when FalseClass, TrueClass: 
							value = @template.t(value.to_s)
						when NilClass:
							value = @template.h("#{object.street} #{object.number}") if attr.to_sym == :address && object.respond_to?(:street) && object.respond_to?(:number)
						when String:
							value = @template.link_to(value, "mailto:#{value}") if attr.to_sym == :email && value.present?
						else
							value = @template.number_to_currency(value) if attr.to_s.match(/price$/)
					end
				end

				value = @options[:blank_text] if value.blank? && (@options || {})[:blank_text].present?

				return value
			end
		end

		class ExtraShowBuilder < SimpleShowBuilder
			def from_until_attribute(attr, options = {})
				render_attribute(
					attribute_name_content(@object, attr, options),
					[(attribute_value_content(@object, attr.to_s+"_from", options) || ''),
					(attribute_value_content(@object, attr.to_s+"_until", options) || '')].reject(&:blank?).join(options.delete(:join_text) || " / "),
					options.merge(:attribute_name => attr.to_s)
				)
			end
			
			def from_until_attributes(*args)
				options = args.extract_options!
				return args.map{|arg| self.from_until_attribute(arg, options)}.join
			end
		end

		class SimpleCrudPageBuilder < GeneralBuilder
			def initialize(object, template)
				@object, @template = object, template
			end

			def crud_page(*args, &proc)
				options = args.extract_options!
				default_handler(:render_crud_page, *(args+[options.merge(:builder => self)]), &proc)
			end

			def title(content, options = {})
				render_title content, options
			end

			def default_title
			end

			def links(*args, &proc)
				default_handler(:render_links, *args, &proc)
			end

			def content(*args, &proc)
				default_handler(:render_content, *args, &proc)
			end

			private

			def render_crud_page(content, options)
				options[:class] ||= 'crud_page'
				@template.content_tag :div, content, options
			end

			def render_title(content, options)
				@template.content_tag :h1, content, options
			end

			def render_links(content, options)
				render_content_tag_with_forced_class(:div, 'links', content, options)
			end

			def render_content(content, options)
				# nothing special here
				return content
			end
		end

	end

	class Base
		cattr_accessor :default_list_builder, :default_show_builder, :default_crud_page_builder
		self.default_list_builder = ::ViewBuilders::Builders::PuristListBuilder
		self.default_show_builder = ::ViewBuilders::Builders::SimpleShowBuilder
		self.default_crud_page_builder = ::ViewBuilders::Builders::SimpleCrudPageBuilder
	end
end

