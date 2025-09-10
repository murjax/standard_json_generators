require "json"

task :schema_to_json do
  path = "#{ARGV[1]}/db/schema.rb"

  if File.exist?(path)
    schema = File.read(path)
    tables = parse_schema_tables(schema)

    tables.each do |table|
      table_name = table["model_name"].underscore.pluralize
      output = JSON.pretty_generate(table)
      File.write("#{table_name}_schema_test.json", output)
    end
  else
    puts "schema not found"
  end
end

def parse_schema_tables(schema_content)
  tables = []

  # Match create_table blocks
  table_matches = schema_content.scan(/create_table\s+"([^"]+)".*?do \|t\|(.*?)end/m)

  table_matches.each do |table_name, table_body|
    model_name = table_name.singularize.camelize
    columns = parse_table_columns(table_body)

    tables << {
      "model_name" => model_name,
      "columns" => columns
    }
  end

  tables
end

def parse_table_columns(table_body)
  columns = []

  # Common column patterns in schema files
  column_patterns = [
    # t.string "name", null: false
    /t\.(\w+)\s+"([^"]+)"(?:,\s*(.+))?/,
    # t.references :user, null: false, foreign_key: true
    /t\.references\s+:(\w+)(?:,\s*(.+))?/,
    # t.belongs_to :user, null: false, foreign_key: true
    /t\.belongs_to\s+:(\w+)(?:,\s*(.+))?/
  ]

  table_body.lines.each do |line|
    line = line.strip
    next if line.empty? || line.start_with?('#')

    # Handle references/belongs_to separately
    if line.match(/t\.(references|belongs_to)\s+:(\w+)/)
      type = $1
      column_name = "#{$2}_id"
      options = $' # Everything after the match

      null_allowed = !options.match(/null:\s*false/)

      columns << {
        "name" => column_name,
        "type" => "reference",
        "null" => null_allowed
      }
      next
    end

    # Handle regular columns
    column_patterns.each do |pattern|
      if match = line.match(pattern)
        column_type = match[1]
        column_name = match[2]
        options = match[3] || ""

        # Skip if this is a references match (already handled above)
        next if column_type == 'references' || column_type == 'belongs_to'

        # Parse null constraint
        null_allowed = true
        if options.match(/null:\s*false/)
          null_allowed = false
        elsif options.match(/null:\s*true/)
          null_allowed = true
        end

        # Map Rails types to simplified types
        simplified_type = map_column_type(column_type)

        columns << {
          "name" => column_name,
          "type" => simplified_type,
          "null" => null_allowed
        }
        break
      end
    end
  end

  columns
end

def map_column_type(rails_type)
  type_mapping = {
    'string' => 'string',
    'text' => 'string',
    'integer' => 'integer',
    'bigint' => 'integer',
    'decimal' => 'decimal',
    'float' => 'float',
    'boolean' => 'boolean',
    'date' => 'date',
    'datetime' => 'datetime',
    'timestamp' => 'datetime',
    'time' => 'time',
    'binary' => 'binary',
    'json' => 'json',
    'jsonb' => 'json'
  }

  type_mapping[rails_type] || rails_type
end
