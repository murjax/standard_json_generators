class JsonGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  argument :json_file, type: :string
  attr_reader :json_config, :target_directory, :model_name, :model_name_plural, :model_name_underscore

  def read_file
    data = File.read(json_file)
    @json_config = JSON.parse(data)
    @target_directory = @json_config["target_directory"] || Rails.root
    @model_name = @json_config["model_name"]
    @model_name_underscore = @model_name.underscore
    @model_name_plural = @model_name_underscore.pluralize
  end

  def create_model
    return unless @json_config.dig("enabled_generators", "model")

    template "model.rb.erb", "#{target_directory}/app/models/#{@model_name_underscore}.rb"
  end

  def create_migration
    return unless @json_config.dig("enabled_generators", "migration")

    template "migration.rb.erb", "#{target_directory}/db/migrate/#{Time.now.utc.strftime("%Y%m%d%H%M%S")}_create_#{@model_name_plural}.rb"
  end

  def create_controller
    return unless @json_config.dig("enabled_generators", "controller")

    template "controller.rb.erb", "#{target_directory}/app/controllers/#{@model_name_plural}_controller.rb"
  end

  def create_views
    return unless @json_config.dig("enabled_generators", "views")

    template "index.html.erb", "#{target_directory}/app/views/#{model_name_plural}/index.html.erb"
    template "full_table.html.erb", "#{target_directory}/app/views/#{model_name_plural}/_full_table.html.erb"
    template "mobile_list.html.erb", "#{target_directory}/app/views/#{model_name_plural}/_mobile_list.html.erb"
    template "form.html.erb", "#{target_directory}/app/views/#{model_name_plural}/_form.html.erb"
    template "new.html.erb", "#{target_directory}/app/views/#{model_name_plural}/new.html.erb"
    template "edit.html.erb", "#{target_directory}/app/views/#{model_name_plural}/edit.html.erb"
    template "show.html.erb", "#{target_directory}/app/views/#{model_name_plural}/show.html.erb"
  end
end
