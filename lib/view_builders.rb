module ViewBuilders
	module Helpers
		def list_html(*args, &proc)
			options = args.extract_options!

			builder_class = options[:builder] || ViewBuilders::Base.default_list_builder
			builder = builder_class.new(self)
			builder.list(&proc)
		end

		def show_html(*args, &proc)
			options = args.extract_options!

			builder_class = options[:builder] || ViewBuilders::Base.default_show_builder
			builder = builder_class.new(nil, self)
			builder.show(&proc)
		end

		def show_for(object, *args, &proc)
			options = args.extract_options!

			builder_class = options[:builder] || ViewBuilders::Base.default_show_builder
			builder = builder_class.new(object, self)
			builder.show(&proc)
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
				@template.content_tag(:ul, content, {:class => "list"}.merge(options))
			end

			def render_row(content, options)
				@template.content_tag(:li, content, {:class => "row"}.merge(options))
			end
		end


		class SimpleShowBuilder < GeneralBuilder
			def initialize(object, template)
				@object, @template = object, template
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
					options.delete(:name) || attribute_name_content(@object, attr, options),
					options.delete(:value) || attribute_value_content(@object, attr, options),
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
				content = render_attribute_name(name, options[:name_options] || {}) + render_attribute_value(value, options[:value_options] || {})
				render_content_tag_with_forced_class(:li, li_class, content, options)
			end

			def render_attribute_name(content, options)
				render_content_tag_with_forced_class(:div, 'name', content, options)
			end

			def render_attribute_value(content, options)
				render_content_tag_with_forced_class(:div, 'value', content, options)
			end

			def attribute_name_content(object, attr, options = {})
				object.class.human_attribute_name attr
			end

			def attribute_value_content(object, attr, options = {})
				value = object.respond_to?(attr) ? object.send(attr) : nil

				case value
					when Date, Time, DateTime:
						value = @template.l(value)
					when FalseClass, TrueClass:
						value = @template.t(value.to_s)
					when NilClass:
						value = @template.h("#{object.street} #{object.number}") if attr.to_sym == :address && object.respond_to?(:street) && object.respond_to?(:number)
					when String:
						value = @template.link_to(value, "mailto:#{value}") if attr.to_sym == :email
					else
						value = @template.number_to_currency(value) if attr.to_s.match(/price$/)
				end

				return value
			end
		end


	end

	class Base
		cattr_accessor :default_list_builder, :default_show_builder
		self.default_list_builder = ::ViewBuilders::Builders::PuristListBuilder
		self.default_show_builder = ::ViewBuilders::Builders::SimpleShowBuilder
	end
end

