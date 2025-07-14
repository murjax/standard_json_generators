class JsonGenerator < JsonGeneratorCore::Generators::JsonBase
  source_root File.expand_path("templates", __dir__)

  def setup
    @markdown = []
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
    @new_columns = @json_config["columns"].reject { |column| @existing_columns.include?(column["name"]) }
  end

  # def create_model
  #   return unless @json_config.dig("enabled_generators", "model")
  #
  #   template "model.rb.erb", "#{target_directory}/app/models/#{@model_name_underscore}.rb"
  # end
  #
  # def create_migration
  #   return unless @json_config.dig("enabled_generators", "migration")
  #
  #   template "migration.rb.erb", "#{target_directory}/db/migrate/#{Time.now.utc.strftime("%Y%m%d%H%M%S")}_create_#{@model_name_plural}.rb"
  # end
  #
  # def create_controller
  #   return unless @json_config.dig("enabled_generators", "controller")
  #
  #   template "controller.rb.erb", "#{target_directory}/app/controllers/#{@model_name_plural}_controller.rb"
  # end
  #
  def create_views
    return unless @json_config.dig("enabled_generators", "views")

    path = "#{target_directory}/app/views/#{model_name_plural}/index.html.erb"
    unless @json_config["print_additions_to_markdown"]
      template "index.html.erb", path
    end

    path = "#{target_directory}/app/views/#{model_name_plural}/_full_table.html.erb"
    if @json_config["print_additions_to_markdown"]
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

      markdown_output = <<~MARKDOWN
        #{path}
        #{table_headers.join("\n")}
        #{table_columns.join("\n")}
      MARKDOWN

      @markdown.push(markdown_output)
    else
      template "full_table.html.erb", path
    end

    path = "#{target_directory}/app/views/#{model_name_plural}/_mobile_list.html.erb"
    unless @json_config["print_additions_to_markdown"]
      template "mobile_list.html.erb", path
    end

    path = "#{target_directory}/app/views/#{model_name_plural}/_form.html.erb"
    if @json_config["print_additions_to_markdown"]
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

      markdown_output = <<~MARKDOWN
        #{path}
        #{inputs.join("\n")}
      MARKDOWN

      @markdown.push(markdown_output)
    else
      template "form.html.erb", path
    end

    path = "#{target_directory}/app/views/#{model_name_plural}/new.html.erb"
    unless @json_config["print_additions_to_markdown"]
      template "new.html.erb", path
    end

    path = "#{target_directory}/app/views/#{model_name_plural}/edit.html.erb"
    unless @json_config["print_additions_to_markdown"]
      template "edit.html.erb", path
    end

    path = "#{target_directory}/app/views/#{model_name_plural}/show.html.erb"
    if @json_config["print_additions_to_markdown"]
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

      markdown_output = <<~MARKDOWN
        #{path}
        #{fields.join("\n")}
      MARKDOWN

      @markdown.push(markdown_output)
    else
      template "show.html.erb", path
    end
  end

  # def create_cypress_tests
  #   return unless @json_config.dig("enabled_generators", "cypress")
  #
  #   template "show.cy.js.erb", "#{target_directory}/e2e/cypress/e2e/#{model_name_plural}/show.cy.js"
  #   template "new.cy.js.erb", "#{target_directory}/e2e/cypress/e2e/#{model_name_plural}/new.cy.js"
  #   template "edit.cy.js.erb", "#{target_directory}/e2e/cypress/e2e/#{model_name_plural}/edit.cy.js"
  #   template "full_index.cy.js.erb", "#{target_directory}/e2e/cypress/e2e/#{model_name_plural}/full_index.cy.js"
  #   template "mobile_index.cy.js.erb", "#{target_directory}/e2e/cypress/e2e/#{model_name_plural}/mobile_index.cy.js"
  # end

  def wrapup
    if @json_config["print_additions_to_markdown"]
      final_markdown = @markdown.join("\n")
      File.write("generator_output.md", final_markdown)
    end
  end
end
