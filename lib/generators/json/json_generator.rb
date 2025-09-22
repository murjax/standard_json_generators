class JsonGenerator < JsonGeneratorCore::Generators::JsonBase
  source_root File.expand_path("templates", __dir__)

  def setup
    @markdown = []
    find_existing_columns
    @columns = @new_columns if @json_config["new_columns_only"]
    @presence_columns = @columns.filter { |column| column["null"] == false }
    @model_name_camel = @model_name.camelize(:lower)
  end

  def create_migration
    return unless @json_config.dig("enabled_generators", "migration")

    if @json_config["new_columns_only"].present? && @existing_columns.length.positive? && @new_columns.length != @existing_columns.length
      template_with_markdown(
        template_name: "new_column_migration.rb.erb",
        path: "db/migrate/#{Time.now.utc.strftime("%Y%m%d%H%M%S")}_add_columns_to_#{@model_name_plural}.rb"
      )
    else
      template_with_markdown(
        template_name: "migration.rb.erb",
        path: "db/migrate/#{Time.now.utc.strftime("%Y%m%d%H%M%S")}_create_#{@model_name_plural}.rb"
      )
    end
  end

  def filter_migration_only_columns
    @columns = @columns.filter { |column| !column["migration_only"] }
  end

  def create_model
    return unless @json_config.dig("enabled_generators", "model")

    template_with_markdown(
      template_name: "model.rb.erb",
      path: "app/models/#{@model_name_underscore}.rb"
    )
  end

  def create_controller
    return unless @json_config.dig("enabled_generators", "controller")

    template_with_markdown(
      template_name: "controller.rb.erb",
      path: "app/controllers/#{@model_name_plural}_controller.rb"
    )
  end

  def create_api_controller
    return unless @json_config.dig("enabled_generators", "api_controller")

    template_with_markdown(
      template_name: "api_controller.rb.erb",
      path: "app/controllers/api/#{@model_name_plural}_controller.rb"
    )
  end

  def create_stimulus_index_controller
    return unless @json_config.dig("enabled_generators", "stimulus_index_controller")

    template_with_markdown(
      template_name: "index_controller.js.erb",
      path: "app/javascript/controllers/#{@model_name_plural}_index_controller.js",
      use_for_new_columns: false
    )
  end

  def create_views
    return unless @json_config.dig("enabled_generators", "views")

    template_with_markdown(
      template_name: "index.html.erb",
      path: "app/views/#{@model_name_plural}/index.html.erb",
      use_for_new_columns: false
    )
    template_with_markdown(
      template_name: "full_table.html.erb",
      path: "app/views/#{@model_name_plural}/_full_table.html.erb"
    )
    template_with_markdown(
      template_name: "mobile_list.html.erb",
      path: "app/views/#{@model_name_plural}/_mobile_list.html.erb"
    )
    template_with_markdown(
      template_name: "form.html.erb",
      path: "app/views/#{@model_name_plural}/_form.html.erb"
    )

    unless @json_config.dig("use_modals_for_forms")
      template_with_markdown(
        template_name: "new.html.erb",
        path: "app/views/#{@model_name_plural}/new.html.erb",
        use_for_new_columns: false
      )
      template_with_markdown(
        template_name: "edit.html.erb",
        path: "app/views/#{@model_name_plural}/edit.html.erb",
        use_for_new_columns: false
      )
    end

    template_with_markdown(
      template_name: "show.html.erb",
      path: "app/views/#{@model_name_plural}/show.html.erb"
    )
  end

  def create_form_functions
    return unless @json_config.dig("enabled_generators", "form_functions")

    template_with_markdown(
      template_name: "form_functions.js",
      path: "app/javascript/custom/forms.js"
    )
  end

  def create_modal_partial
    return unless @json_config.dig("enabled_generators", "modal_partial")

    template_with_markdown(
      template_name: "modal.html.erb",
      path: "app/views/layouts/modal.html.erb"
    )
  end

  def create_cypress_tests
    return unless @json_config.dig("enabled_generators", "cypress")

    template_with_markdown(
      template_name: "show.cy.js.erb",
      path: "e2e/cypress/e2e/#{@model_name_plural}/show.cy.js"
    )
    template_with_markdown(
      template_name: "new.cy.js.erb",
      path: "e2e/cypress/e2e/#{@model_name_plural}/new.cy.js"
    )
    template_with_markdown(
      template_name: "edit.cy.js.erb",
      path: "e2e/cypress/e2e/#{@model_name_plural}/edit.cy.js"
    )
    template_with_markdown(
      template_name: "full_index.cy.js.erb",
      path: "e2e/cypress/e2e/#{@model_name_plural}/full_index.cy.js"
    )
    template_with_markdown(
      template_name: "mobile_index.cy.js.erb",
      path: "e2e/cypress/e2e/#{@model_name_plural}/mobile_index.cy.js"
    )
  end

  def save_markdown
    return unless @json_config["save_to_markdown"]

    File.write("#{target_directory}/generator_output.md", @markdown.join("\n"))
  end

  private

  def find_existing_columns
    unless File.exist?("#{target_directory}/db/schema.rb")
      @existing_columns = []
      @new_columns = @columns
      return
    end

    schema = File.read("#{target_directory}/db/schema.rb")

    pattern = /create_table\s+"#{@model_name_plural}".*?do\s*\|t\|(.*?)^\s*end/m
    match = schema.scan(pattern)

    columns = []

    unless match[0].present?
      @existing_columns = []
      @new_columns = @columns
      return
    end

    match[0][0].scan(/^\s*t\.(\w+)\s+"([^"]+)"/) do |_type, name|
      columns.push(name)
    end

    @existing_columns = columns
    @new_columns = @columns.reject do |column|
      column_ref = (column["type"] == "reference") ? "#{column["name"]}_id" : column["name"]
      @existing_columns.include?(column_ref)
    end
  end

  def template_with_markdown(template_name:, path:, use_for_new_columns: true)
    return if @json_config["new_columns_only"] && !use_for_new_columns

    if @json_config["save_to_markdown"]
      template template_name, "temp/#{path}"
      content = File.read("temp/#{path}")

      @markdown.push(
        <<~MARKDOWN
          #{path}

          ```
          #{content}
          ```
        MARKDOWN
      )

      File.delete("temp/#{path}")
    else
      template template_name, "#{target_directory}/#{path}"
    end
  end
end
