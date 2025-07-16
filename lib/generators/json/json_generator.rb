class JsonGenerator < JsonGeneratorCore::Generators::JsonBase
  source_root File.expand_path("templates", __dir__)

  def setup
    @markdown = []
    @presence_columns = @json_config["columns"].filter { |column| column["null"] == false }
  end

  def find_existing_columns
    schema = File.read("#{target_directory}/db/schema.rb")

    pattern = /create_table\s+"#{@model_name_underscore}".*?do\s*\|t\|(.*?)^\s*end/m
    match = schema.scan(pattern)

    columns = []

    match[0][0].scan(/^\s*t\.(\w+)\s+"([^"]+)"/) do |_type, name|
      columns.push(name)
    end

    @existing_columns = columns
    @new_columns = @json_config["columns"].reject do |column|
      column_ref = (column["type"] == "reference") ? "#{column["name"]}_id" : column["name"]
      @existing_columns.include?(column_ref)
    end
  end

  def create_model
    return unless @json_config.dig("enabled_generators", "model")

    path = "#{target_directory}/app/models/#{@model_name_underscore}.rb"
    template_with_markdown(path, "model.rb.erb") do |fragments|
      @new_columns.each do |column|
        next unless column["type"] == "reference"

        fragments.push(
          <<~RUBY
            belongs_to :#{column["name"]}
          RUBY
        )
      end

      if @presence_columns.any?
        joined_columns = @presence_columns.map { |column| ":#{column["name"]}" }.join(", ")

        fragments.push(
          <<~RUBY
            validates #{joined_columns}, presence: true
          RUBY
        )
      end
    end
  end

  def create_migration
    return unless @json_config.dig("enabled_generators", "migration")

    if @existing_columns.length.positive? && @new_columns.length != @existing_columns.length
      template "new_column_migration.rb.erb", "#{target_directory}/db/migrate/#{Time.now.utc.strftime("%Y%m%d%H%M%S")}_add_columns_to_#{@model_name_plural}.rb"
    else
      template "migration.rb.erb", "#{target_directory}/db/migrate/#{Time.now.utc.strftime("%Y%m%d%H%M%S")}_create_#{@model_name_plural}.rb"
    end
  end

  def create_controller
    return unless @json_config.dig("enabled_generators", "controller")

    path = "#{target_directory}/app/controllers/#{@model_name_plural}_controller.rb"
    template_with_markdown(path, "controller.rb.erb") do |fragments|
      permitted_columns = @json_config["columns"].map do |column|
        (column["type"] == "reference") ? ":#{column["name"]}_id" : ":#{column["name"]}"
      end.join(", ")

      fragments.push(
        <<~RUBY
          params.require(:<%= @model_name_underscore %>).permit(#{permitted_columns})
        RUBY
      )
    end
  end

  def create_views
    return unless @json_config.dig("enabled_generators", "views")

    path = "#{target_directory}/app/views/#{model_name_plural}/index.html.erb"
    unless @json_config["print_additions_to_markdown"]
      template "index.html.erb", path
    end

    path = "#{target_directory}/app/views/#{model_name_plural}/_full_table.html.erb"
    template_with_markdown(path, "full_table.html.erb") do |fragments|
      table_headers = []
      table_columns = []

      @new_columns.each do |column|
        table_header = <<~HTML
          <th class="p-4 border-b border-blue-gray-100 bg-blue-gray-50">
            <p class="block text-sm antialiased font-normal leading-none text-blue-gray-900 opacity-70">
              #{column["name"].titleize}
            </p>
          </th>
        HTML

        table_column = if column["type"] == "reference"
          <<~HTML
            <td class="p-4 border-b border-blue-gray-50">
              <p class="block text-sm antialiased font-normal leading-normal text-blue-gray-900">
                <%= #{@model_name_underscore}.#{column["name"]}.#{column["display_field"]} %>
              </p>
            </td>
          HTML
        else
          <<~HTML
            <td class="p-4 border-b border-blue-gray-50">
              <p class="block text-sm antialiased font-normal leading-normal text-blue-gray-900">
                <%= #{@model_name_underscore}.#{column["name"]} %>
              </p>
            </td>
          HTML
        end

        table_headers.push(table_header)
        table_columns.push(table_column)
      end

      fragments.push(table_headers.join("\n"))
      fragments.push(table_columns.join("\n"))
    end

    path = "#{target_directory}/app/views/#{model_name_plural}/_mobile_list.html.erb"
    template_with_markdown(path, "mobile_list.html.erb")

    path = "#{target_directory}/app/views/#{model_name_plural}/_form.html.erb"
    template_with_markdown(path, "form.html.erb") do |fragments|
      inputs = []
      @new_columns.each do |column|
        if ["integer", "string"].include?(column["type"])
          inputs.push(
            <<~HTML
              <div class="flex flex-col mb-4">
                <%= form.label :#{column["name"]}, required: true, class: "block mb-2 text-sm font-medium text-gray-900" %>
                <%= form.text_field :#{column["name"]}, class: "border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-full p-2.5" %>
              </div>
            HTML
          )
        elsif column["type"] == "text"
          inputs.push(
            <<~HTML
              <div class="flex flex-col mb-4">
                <%= form.label :#{column["name"]}, required: true, class: "block mb-2 text-sm font-medium text-gray-900" %>
                <%= form.text_area :#{column["name"]}, class: "border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-full p-2.5" %>
              </div>
            HTML
          )
        elsif column["type"] == "reference"
          inputs.push(
            <<~HTML
              <div class="flex flex-col mb-4">
                <%= form.label :#{column["name"]}, required: true, class: "block mb-2 text-sm font-medium text-gray-900" %>
                <%= form.select :#{column["name"]}_id, #{column["name"].camelize}.all.collect { |#{column["name"]}| [#{column["name"]}.#{column["display_name"]}, #{column["name"]}.id] }, { prompt: "Select a #{column["name"]} } %>
              </div>
            HTML
          )
        end
      end

      fragments.push(inputs.join("\n"))
    end

    path = "#{target_directory}/app/views/#{model_name_plural}/new.html.erb"
    template_with_markdown(path, "new.html.erb")

    path = "#{target_directory}/app/views/#{model_name_plural}/edit.html.erb"
    template_with_markdown(path, "edit.html.erb")

    path = "#{target_directory}/app/views/#{model_name_plural}/show.html.erb"
    template_with_markdown(path, "show.html.erb") do |fragments|
      fields = []
      @new_columns.each do |column|
        if column["type"] == "reference"
          fields.push(
            <<~HTML
              <tr>
                <td class="p-4 block md:table-cell">
                  <p class="block text-sm antialiased font-bold leading-normal text-gray-400">
                    #{column["name"].titleize}
                  </p>
                </td>
                <td class="p-4 block md:table-cell">
                  <p class="block text-sm antialiased font-normal leading-normal text-blue-gray-900">
                    <%= @#{@model_name_underscore}.#{column["name"]}.#{column["display_field"]} %>
                  </p>
                </td>
              </tr>
            HTML
          )
        else
          fields.push(
            <<~HTML
              <tr>
                <td class="p-4 block md:table-cell">
                  <p class="block text-sm antialiased font-bold leading-normal text-gray-400">
                    #{column["name"].titleize}
                  </p>
                </td>
                <td class="p-4 block md:table-cell">
                  <p class="block text-sm antialiased font-normal leading-normal text-blue-gray-900">
                    <%= @#{@model_name_underscore}.#{column["name"]} %>
                  </p>
                </td>
              </tr>
            HTML
          )
        end
      end

      fragments.push(fields.join("\n"))
    end
  end

  def create_cypress_tests
    return unless @json_config.dig("enabled_generators", "cypress")

    path = "#{target_directory}/e2e/cypress/e2e/#{model_name_plural}/show.cy.js"
    template_with_markdown(path, "show.cy.js.erb") do |fragments|
      column_fields = @json_config["columns"].map do |column|
        test_data = @json_config["test_data"][column["name"]]
        next unless test_data

        if column["type"] == "reference"
          "#{column["name"]}_id: 1"
        else
          "#{column["name"]}: #{test_data}"
        end
      end.select { |data| data.present? }
      fragments.push(
        <<~JS
          [
            'create',
            '#{@model_name_underscore}',
            {
              #{column_fields.join(",\n    ")}
            }
          ]
        JS
      )

      assertions = @json_config["columns"].map do |column|
        next if column["type"] == "reference"
        test_data = @json_config["test_data"][column["name"]]
        next unless test_data

        "cy.get('[data-test-id=\"#{@model_name_underscore}-info\"]').first().should('contain', '#{test_data}');"
      end.filter { |assertion| assertion.present? }

      fragments.push(
        <<~JS
          #{assertions.join("\n")}
        JS
      )
    end

    path = "#{target_directory}/e2e/cypress/e2e/#{model_name_plural}/new.cy.js"
    template_with_markdown(path, "new.cy.js.erb") do |fragments|
      @reference_columns.each do |column|
        fragments.push(
          <<~JS
            ['create', '#{column["name"]}', { #{column["display_field"]}: '#{@json_config["test_data"][column["name"]]}' }],
          JS
        )
      end

      actions = @json_config["columns"].map do |column|
        test_data = @json_config["test_data"][column["name"]]
        next unless test_data
        input_action = (column["type"] == "reference") ? "select" : "type"
        field_id = (column["type"] == "reference") ? "##{@model_name_underscore}_#{column["name"]}_id" : "##{@model_name_underscore}_#{column["name"]}"

        "cy.get('#{field_id}').#{input_action}('#{test_data}');"
      end.filter { |action| action.present? }

      fragments.push(
        <<~JS
          #{actions.join("\n")}
        JS
      )
    end

    path = "#{target_directory}/e2e/cypress/e2e/#{model_name_plural}/edit.cy.js"
    template_with_markdown(path, "edit.cy.js.erb") do |fragments|
      @reference_columns.each do |column|
        fragments.push(
          <<~JS
            ['create', '#{column["name"]}', { #{column["display_field"]}: '#{@json_config["test_data"][column["name"]]}' }],
          JS
        )
      end

      actions = @json_config["columns"].map do |column|
        test_data = @json_config["test_data"][column["name"]]
        next unless test_data
        input_action = (column["type"] == "reference") ? "select" : "clear().type"
        field_id = (column["type"] == "reference") ? "##{@model_name_underscore}_#{column["name"]}_id" : "##{@model_name_underscore}_#{column["name"]}"

        "cy.get('#{field_id}').#{input_action}('#{test_data}');"
      end.filter { |action| action.present? }

      fragments.push(
        <<~JS
          #{actions.join("\n")}
        JS
      )
    end

    path = "#{target_directory}/e2e/cypress/e2e/#{model_name_plural}/full_index.cy.js"
    template_with_markdown(path, "full_index.cy.js.erb") do |fragments|
      @reference_columns.each do |column|
        test_data = @json_config["test_data"][column["name"]]

        fragments.push(
          <<~JS
            [
              'create',
              '#{column["name"]}',
              {
                id: 1,
                #{column["display_field"]}: '#{test_data}'
              }
          JS
        )
      end

      column_fields = @json_config["columns"].map do |column|
        test_data = @json_config["test_data"][column["name"]]
        next unless test_data

        if column["type"] == "reference"
          "#{column["name"]}_id: 1"
        else
          "#{column["name"]}: #{test_data}"
        end
      end.filter { |data| data.present? }
      fragments.push(
        <<~JS
          [
            'create',
            '#{@model_name_underscore}',
            {
              #{column_fields.join(",\n    ")}
            }
          ]
        JS
      )

      header_assertions = @json_config["columns"].map do |column|
        "cy.get('[data-test-id=\"#{@model_name_plural}-full-table\"] thead tr').should('contain', '#{column["name"].titleize}');"
      end
      fragments.push(
        <<~JS
          #{header_assertions.join("\n")}
        JS
      )

      row_assertions = @json_config["columns"].map do |column|
        test_data = @json_config["test_data"][column["name"]]
        next unless test_data

        "cy.get('[data-test-id=\"#{@model_name_plural}-full-table\"]').get('tbody tr:nth-child(1)').should('contain', '#{test_data}');"
      end.filter { |assertion| assertion.present? }
      fragments.push(
        <<~JS
          #{row_assertions.join("\n")}
        JS
      )
    end

    path = "#{target_directory}/e2e/cypress/e2e/#{model_name_plural}/mobile_index.cy.js"
    template_with_markdown(path, "mobile_index.cy.js.erb") do |fragments|
      @reference_columns.each do |column|
        test_data = @json_config["test_data"][column["name"]]

        fragments.push(
          <<~JS
            [
              'create',
              '#{column["name"]}',
              {
                id: 1,
                #{column["display_field"]}: '#{test_data}'
              }
          JS
        )
      end

      column_fields = @json_config["columns"].map do |column|
        test_data = @json_config["test_data"][column["name"]]
        next unless test_data

        if column["type"] == "reference"
          "#{column["name"]}_id: 1"
        else
          "#{column["name"]}: #{test_data}"
        end
      end.filter { |data| data.present? }
      fragments.push(
        <<~JS
          [
            'create',
            '#{@model_name_underscore}',
            {
              #{column_fields.join(",\n    ")}
            }
          ]
        JS
      )

      display_column = @json_config["columns"].first
      test_data = @json_config["test_data"][display_column["name"]]
      fragments.push(
        <<~JS
          cy.get('[data-test-id="#{@model_name_underscore}-list-item"]').first().should('contain', '#{test_data}');
        JS
      )
    end
  end

  def wrapup
    if @json_config["print_additions_to_markdown"]
      final_markdown = @markdown.join("\n")
      File.write("generator_output.md", final_markdown)
    end
  end

  private

  def template_with_markdown(path, template_name, &block)
    if @json_config["print_additions_to_markdown"]
      fragments = []

      block&.call(fragments)

      return unless fragments.length.positive?

      @markdown.push(
        <<~MARKDOWN
          #{path}
          ```
          #{fragments.join("\n")}
          ```
        MARKDOWN
      )
    else
      template template_name, path
    end
  end
end
