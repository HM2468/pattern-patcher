# frozen_string_literal: true

# app/models/lexeme_processor.rb
class LexemeProcessor < ApplicationRecord
  has_many :process_runs, dependent: :delete_all

  validates :name, :key, :entrypoint, presence: true
  validates :name, length: { maximum: 200 }
  validates :key, uniqueness: true

  validate :entrypoint_must_be_valid_ruby_class_name
  validate :key_must_be_valid_ruby_filename
  validate :default_config_must_be_valid
  validate :output_schema_must_be_valid

  scope :enabled_true, -> { where(enabled: true) }

  # Allowed type collection for output_schema (easy to extend later)
  ALLOWED_SCHEMA_TYPES = %w[string integer number boolean object array].freeze

  # Ensure only one enabled processor exists:
  # - If this record is saved with enabled=true, disable all others in the same transaction.
  before_save :ensure_single_enabled, if: :will_enable?

  class << self
    # Always returns the single enabled record (if any)
    def current_processor
      enabled_true.first
    end
  end

  def config_pretty
    prettier_json(default_config)
  end

  def schema_pretty
    prettier_json(output_schema)
  end

  private

  def will_enable?
    enabled? && (new_record? || will_save_change_to_enabled?)
  end

  # When enabling this record, disable all others.
  # Use update_all to avoid callbacks/validations and keep it fast.
  def ensure_single_enabled
    return unless enabled?

    self.class.where(enabled: true).where.not(id: id).update_all(enabled: false, updated_at: Time.current)
  end

  # entrypoint validations
  # Requirement: valid Ruby class name (supports module namespaces)
  # Example: "LocalizeRails" / "LexemeProcessors::LocalizeRails"
  def entrypoint_must_be_valid_ruby_class_name
    return if entrypoint.blank?

    # Ruby constant name rules: each segment starts with uppercase, followed by letters, numbers, or underscores
    # Namespaces use ::
    unless /\A[A-Z]\w*(?:::[A-Z]\w*)*\z/.match?(entrypoint.to_s)
      errors.add(:entrypoint, "must be a valid Ruby class name, e.g. LocalizeRails or LexemeProcessors::LocalizeRails")
    end
  end

  # key validations
  # Requirement: key + ".rb" must be a valid filename
  # - No path separators allowed (/ or \\)
  # - Cannot be .. or .
  # - Only [a-z0-9_] allowed
  def key_must_be_valid_ruby_filename
    return if key.blank?

    base = key.to_s

    if base == "." || base == ".."
      errors.add(:key, "cannot be '.' or '..'")
      return
    end

    if base.include?("/") || base.include?("\\")
      errors.add(:key, "must be a filename, not a path")
      return
    end

    unless /\A[a-z0-9_]+\z/.match?(base)
      errors.add(:key, "must contain only lowercase letters, numbers, and underscores (e.g. localize_rails)")
      return
    end

    filename = "#{base}.rb"
    # Simple filename validation fallback (to prevent weird characters)
    unless /\A[a-z0-9_]+\.(rb)\z/.match?(filename)
      errors.add(:key, "produces an invalid filename: #{filename.inspect}")
    end
  end


  # default_config validations
  # Requirements:
  # - Must have use_llm field, which must be boolean
  # - Must have llm_provider / llm_model / batch_token_limit when use_llm=true
  def default_config_must_be_valid
    cfg = default_config

    unless cfg.is_a?(Hash)
      errors.add(:default_config, "must be a Hash")
      return
    end

    unless cfg.key?("use_llm") || cfg.key?(:use_llm)
      errors.add(:default_config, "must include use_llm (boolean)")
      return
    end

    use_llm = cfg["use_llm"]
    use_llm = cfg[:use_llm] if use_llm.nil?

    unless use_llm == true || use_llm == false
      errors.add(:default_config, "use_llm must be boolean (true/false)")
      return
    end

    return unless use_llm

    llm_provider = cfg["llm_provider"] || cfg[:llm_provider]
    llm_model = cfg["llm_model"] || cfg[:llm_model]
    batch_token_limit = cfg["batch_token_limit"] || cfg[:batch_token_limit]

    errors.add(:default_config, "llm_provider is required when use_llm is true") if llm_provider.blank?
    errors.add(:default_config, "llm_model is required when use_llm is true") if llm_model.blank?

    if batch_token_limit.nil?
      errors.add(:default_config, "batch_token_limit is required when use_llm is true")
    else
      # Allow string numbers, but must eventually convert to integer > 0
      int_val = begin
        Integer(batch_token_limit)
      rescue ArgumentError, TypeError
        nil
      end

      if int_val.nil? || int_val <= 0
        errors.add(:default_config, "batch_token_limit must be a positive integer when use_llm is true")
      end
    end
  end

  # output_schema validations
  # Requirements:
  # - Must be a non-empty Hash
  # - Keys must be non-empty Strings (symbols will throw errors to avoid confusion)
  # - Values must be allowed type strings
  # - processed_text field must exist (hard requirement)
  def output_schema_must_be_valid
    schema = output_schema

    if schema.nil?
      errors.add(:output_schema, "must be a Hash, got nil")
      return
    end

    unless schema.is_a?(Hash)
      errors.add(:output_schema, "must be a Hash, got #{schema.class}")
      return
    end

    if schema.empty?
      errors.add(:output_schema, "cannot be empty")
      return
    end

    if schema.size > 50
      errors.add(:output_schema, "is too large (max 50 keys)")
      return
    end

    # processed_text must exist (supports string keys; jsonb usually reads as string keys)
    unless schema.key?("processed_text")
      errors.add(:output_schema, "must include required key 'processed_text'")
    end

    schema.each do |k, v|
      unless k.is_a?(String) && k.present?
        errors.add(:output_schema, "key must be a non-empty String, got #{k.inspect} (#{k.class})")
        next
      end

      unless v.is_a?(String) && v.present?
        errors.add(:output_schema, "type for #{k.inspect} must be a non-empty String, got #{v.inspect} (#{v.class})")
        next
      end

      unless ALLOWED_SCHEMA_TYPES.include?(v)
        errors.add(:output_schema, "type for #{k.inspect} must be one of #{ALLOWED_SCHEMA_TYPES.join(', ')}, got #{v.inspect}")
      end
    end
  end
end