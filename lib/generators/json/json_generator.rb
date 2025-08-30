class JsonGenerator < JsonGeneratorCore::Generators::JsonBase
  source_root File.expand_path("templates", __dir__)

  def setup
    @markdown = []
    find_existing_columns
    @columns = @new_columns if @json_config["new_columns_only"]
    @presence_columns = @columns.filter { |column| column["null"] == false }
  end

  def create_migration
    return unless @json_config.dig("enabled_generators", "migration")

    if @json_config["new_columns_only"].present? && @existing_columns.length.positive? && @new_columns.length != @existing_columns.length
      template_with_markdown "new_column_migration.rb.erb", "db/migrate/#{Time.now.utc.strftime("%Y%m%d%H%M%S")}_add_columns_to_#{@model_name_plural}.rb"
    else
      template_with_markdown "migration.rb.erb", "db/migrate/#{Time.now.utc.strftime("%Y%m%d%H%M%S")}_create_#{@model_name_plural}.rb"
    end
  end

  def filter_migration_only_columns
    @columns = @columns.filter { |column| !column["migration_only"] }
  end

  def create_model
    return unless @json_config.dig("enabled_generators", "model")

    template_with_markdown "model.rb.erb", "app/models/#{@model_name_underscore}.rb"
  end

  def create_controller
    return unless @json_config.dig("enabled_generators", "controller")

    template_with_markdown "controller.rb.erb", "app/controllers/#{@model_name_plural}_controller.rb"
  end

  def create_views
    return unless @json_config.dig("enabled_generators", "views")

    template_with_markdown "index.html.erb", "app/views/#{@model_name_plural}/index.html.erb"
    template_with_markdown "full_table.html.erb", "app/views/#{@model_name_plural}/_full_table.html.erb"
    template_with_markdown "mobile_list.html.erb", "app/views/#{@model_name_plural}/_mobile_list.html.erb"
    template_with_markdown "form.html.erb", "app/views/#{@model_name_plural}/_form.html.erb"
    template_with_markdown "new.html.erb", "app/views/#{@model_name_plural}/new.html.erb"
    template_with_markdown "edit.html.erb", "app/views/#{@model_name_plural}/edit.html.erb"
    template_with_markdown "show.html.erb", "app/views/#{@model_name_plural}/show.html.erb"
  end

  def create_cypress_tests
    return unless @json_config.dig("enabled_generators", "cypress")

    template_with_markdown "show.cy.js.erb", "e2e/cypress/e2e/#{@model_name_plural}/show.cy.js"
    template_with_markdown "new.cy.js.erb", "e2e/cypress/e2e/#{@model_name_plural}/new.cy.js"
    template_with_markdown "edit.cy.js.erb", "e2e/cypress/e2e/#{@model_name_plural}/edit.cy.js"
    template_with_markdown "full_index.cy.js.erb", "e2e/cypress/e2e/#{@model_name_plural}/full_index.cy.js"
    template_with_markdown "mobile_index.cy.js.erb", "e2e/cypress/e2e/#{@model_name_plural}/mobile_index.cy.js"
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

  def template_with_markdown(template_name, path)
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
