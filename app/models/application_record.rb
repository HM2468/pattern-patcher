class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  private

  def prettier_json(value)
    return "" if value.nil?

    JSON.pretty_generate(value.as_json)
  rescue JSON::GeneratorError, TypeError
    value.to_json
  end
end
