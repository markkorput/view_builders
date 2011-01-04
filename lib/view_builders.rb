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

		module GeneralBuilderMethods
			private

			def default_handler(method, *args, &proc)
				options = args.extract_options!
				content = self.send(method, block_given? ? @template.capture(options.delete(:builder), &proc) : args.first, options)
				block_given? ? @template.concat(content) : content
			end

			def render_content_tag_with_forced_class(type, classname, content, options = {})
				@template.content_tag type, content, options.merge(classname.blank? ? {} : {:class => [classname, options[:class]].reject(&:blank?).join(" ")})
			end
		end

		class GeneralBuilder
			include GeneralBuilderMethods

			def initialize(template)
				@template = template
			end
		end


		# LIST builders
		class VerySimpleListBuilder < GeneralBuilder #:nodoc:
			def list(*args, &proc)
				options = args.extract_options!
				@column_classes = options.delete(:column_classes)
				default_handler(:render_list, *(args+[options.merge(:builder => self)]), &proc)
			end

			def header_row(*args, &proc)
				@current_column = nil
				default_handler(:render_header_row, *args, &proc)
			end

			alias :header :header_row

			def row(*args, &proc)
				options = args.extract_options!

				@current_column = nil

				# add the classname 'odd' to every other row, skipping rows which got the :cycle => false options parameter
				if options.delete(:cycle) != false
					# add the cycling odd class to the options[:class] options (space-seperated)
					options.merge!(:class => [@template.cycle('odd', nil), options[:class]].reject(&:blank?).join(' '))
					# remove the class options if it turned up blank
					options.delete(:class) if options[:class].blank?
				end

				default_handler(:render_row, *(args << options), &proc)
			end

			def header_column(*args, &proc)
				if @column_classes.present?
					@current_column = (@current_column || -1) + 1
					options = args.extract_options!
					args << options.merge(:class => options[:class] || @column_classes[@current_column])
				end

				default_handler(:render_header_column, *args, &proc)
			end

			def column(*args, &proc)
				if @column_classes.present?
					@current_column = (@current_column || -1) + 1
					options = args.extract_options!
					args << options.merge(:class => options[:class] || @column_classes[@current_column])
				end

				default_handler(:render_column, *args, &proc)
			end

			alias :header_col :header_column
			alias :col :column

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
				render_content_tag_with_forced_class(:li, "row", content, options)
			end

			def render_header_row(content, options)
				render_content_tag_with_forced_class(:li, 'row header', content, options)
			end
		end

		class TableListBuilder < VerySimpleListBuilder #:nodoc:

			private

			def render_list(content, options)
				render_content_tag_with_forced_class(:table, 'list', content, options)
				# @template.content_tag(:ul, content, {:class => "list"}.merge(options))
			end

			def render_row(content, options)
				#@template.content_tag(:li, content, {:class => "row#{@template.cycle(' odd', '')}"}.merge(options))
				# render_content_tag_with_forced_class(:tr, @template.cycle('odd', nil), content, options)
				@template.content_tag :tr, content, options
			end

			def render_header_row(content, options)
				@template.content_tag(:thead, @template.content_tag(:tr, content, options))
				#render_content_tag_with_forced_class(:tr, 'header', content, options)
			end

			def render_column(content, options)
				@template.content_tag(:td, content, options)
				#render_content_tag_with_forced_class(:td, 'column', content, options)
			end

			def render_header_column(content, options)
				@template.content_tag(:th, content, options)
				#render_content_tag_with_forced_class(:td, 'column', content, options)
			end
		end

		# SHOW builders
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
				render_options = options.reject{|key, value| [:input, :value].include?(key.to_sym)}.merge(:attribute_name => attr.to_s)

				if options.delete(:cycle) != false
					render_options[:class] = [@template.cycle('odd', nil), render_options[:class]].reject(&:blank?).join(' ')
					render_options.delete(:class) if render_options[:class].blank?
				end

				options.reject{|key, value| [:input, :value].include?(key.to_sym)}.merge(:attribute_name => attr.to_s)
				render_attribute(
					attribute_name_content(@object, attr, options),
					attribute_value_content(@object, attr, options),
					render_options
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
				klass = options.delete(:attribute_name)
				content = render_attribute_name(name, options.delete(:name_options) || {}) + render_attribute_value(value, options.delete(:value_options) || {})
				render_content_tag_with_forced_class(:li, klass, content, options)
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
							value = value.gsub("\r\n", "\n").gsub("\n\r", "\n").gsub("\n", "<br/>")
						else
							value = @template.number_to_currency(value) if attr.to_s.match(/price$/)
					end
				end

				value = @options[:blank_text] if value.blank? && (@options || {})[:blank_text].present?

				return value
			end
		end

		class TableShowBuilder < SimpleShowBuilder
			private

			def render_show(content, options)
				render_content_tag_with_forced_class(:table, "show#{@object ? " " + @template.dom_class(@object) : ''}", content, options)
			end

			def render_attribute(name, value, options = {})
				klass = options.delete(:attribute_name)
				content = render_attribute_name(name, options.delete(:name_options) || {}) + render_attribute_value(value, options.delete(:value_options) || {})
				render_content_tag_with_forced_class(:tr, klass, content, options)
			end

			def render_attribute_name(content, options)
				render_content_tag_with_forced_class(:td, 'name', content, options)
			end

			def render_attribute_value(content, options)
				render_content_tag_with_forced_class(:td, 'value', content, options)
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

		# PAGE builders
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

		# FORM builders
		class SimpleFormBuilder < ActionView::Helpers::FormBuilder
			include GeneralBuilderMethods

			def field_html(*args, &proc)
				default_handler(:render_field, *args, &proc)
			end

			def label_html(*args, &proc)
				default_handler(:render_field_label, *args, &proc)
			end

			def input_html(*args, &proc)
				default_handler(:render_field_input, *args, &proc)
			end

			def field(attr, options = {})
				render_field(
					render_field_label(render_label_content(attr, options)) +
					render_field_input(render_input_content(attr, options)),
					{:field_name => attr.to_s}
				)
			end

			def fields(*args)
				options = args.extract_options!
				return args.map{|arg| self.field(arg, options)}.join
			end

			def label_for(attr, options = {})
				self.label(attr, object.class.respond_to?(:human_attribute_name) ? object.class.human_attribute_name(attr.to_s) : '', options)
			end

			private

			def render_field(content, options = {})
				render_content_tag_with_forced_class(:div, ['field', options.delete(:field_name)].compact.join(' ') , content)
			end

			def render_field_label(content, options = {})
				render_content_tag_with_forced_class(:div, 'label', content, options)
			end

			def render_field_input(content, options = {})
				render_content_tag_with_forced_class(:div, 'input', content, options)
			end

			def render_label_content(attr, options = {})
				options.delete(:label) || label_for(attr, options.delete(:label_options) || {})
			end

			def render_input_content(attr, options = {})
				return options.delete(:input) if !options[:input].nil?

				database_column = object.class.respond_to?(:columns) ? object.class.columns.find{|column| column.name == attr.to_s} : nil
				type = database_column.try(:type) || :string

				if (select_options = options.delete(:select)).is_a?(Array)
					return self.select(attr, select_options, options)
				else
					if type == :string
						if attr.to_s.match(/^password/)
							return self.password_field(attr, options)
						else
							return self.text_field(attr, options)
						end
					else
						return ''
					end
				end
			end

		end
	end

	class Base
		cattr_accessor :default_list_builder, :default_show_builder, :default_crud_page_builder
		self.default_list_builder = ::ViewBuilders::Builders::TableListBuilder
		self.default_show_builder = ::ViewBuilders::Builders::TableShowBuilder
		self.default_crud_page_builder = ::ViewBuilders::Builders::SimpleCrudPageBuilder
	end
end

