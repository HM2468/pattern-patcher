# frozen_string_literal: true
require 'digest'

class HashUtilError < StandardError; end

module HashUtilConcern
  module_function

  # Generate a truncated SHA256 hex string for any content.
  #
  # @param content [Object] any object convertible to string
  # @param length [Integer] hex string length (must be even)
  # @return [String] hex string
  # @raise [HashUtilError] if length is not an Integer or not even
  def hash_string(content, length: 32)
    unless length.is_a?(Integer)
      raise HashUtilError, "GET HASHED KEY ERR: len must be an integer"
    end
    if length.odd?
      raise HashUtilError, "GET HASHED KEY ERR: len should be an even integer"
    end

    content_str = content.to_s
    full_hex = Digest::SHA256.hexdigest(content_str)

    # Python version: digest bytes truncated to length/2, then hex.
    # Equivalent in Ruby: hex chars truncated to `length`.
    full_hex[0, length]
  end

  # Safely dig into a nested hash.
  # Optionally delete the final key and return the deleted value.
  #
  # @param nested_hash [Hash]
  # @param keys [Array<Object>]
  # @param delete [Boolean]
  # @return [Object, nil]
  def dig_nested_hash(nested_hash, keys, delete: false)
    current = nested_hash

    keys.each_with_index do |key, i|
      return nil unless current.is_a?(Hash)

      if i == keys.length - 1 && delete
        return current.delete(key)
      end

      current = current[key]
    end

    current
  end

  # Safely set a value inside a nested hash, creating intermediate hashes.
  # Mutates the original hash (like the Python version).
  #
  # @param nested_hash [Hash]
  # @param keys [Array<Object>]
  # @param value [Object]
  # @return [Hash] the same hash instance
  def set_nested_hash(nested_hash, keys, value)
    current = nested_hash

    keys[0...-1].each do |key|
      current[key] = {} unless current[key].is_a?(Hash)
      current = current[key]
    end

    current[keys[-1]] = value unless keys.empty?
    nested_hash
  end

  # Flatten a nested hash to a single-level hash, joining keys with a splitter.
  #
  # @param nested_hash [Hash]
  # @param splitter [String]
  # @return [Hash<String, Object>]
  def flatten_nested_hash(nested_hash, splitter: ".")
    result = {}

    walk = lambda do |current_hash, parent_key|
      current_hash.each do |k, v|
        full_key = parent_key.nil? || parent_key.empty? ? k.to_s : "#{parent_key}#{splitter}#{k}"
        if v.is_a?(Hash)
          walk.call(v, full_key)
        else
          result[full_key] = v
        end
      end
    end

    walk.call(nested_hash, "")
    result
  end

  # Recursively traverse a nested hash and apply a function to each leaf value.
  # Mutates the original hash in-place.
  #
  # The block receives:
  # - path: Array of keys representing the nested path
  # - value: leaf value
  #
  # @param nested_hash [Hash]
  # @yieldparam path [Array<Object>]
  # @yieldparam value [Object]
  # @yieldreturn [Object] new value
  # @return [Hash]
  def map_nested_hash(nested_hash, &block)
    raise HashUtilError, "block is required" unless block_given?

    mapper = lambda do |current_hash, path|
      current_hash.each do |k, v|
        current_path = path + [k]
        if v.is_a?(Hash)
          mapper.call(v, current_path)
        else
          current_hash[k] = yield(current_path, v)
        end
      end
    end

    mapper.call(nested_hash, [])
    nested_hash
  end

  # Split a large (single-level) hash into an array of smaller hashes, preserving order.
  #
  # @param original_hash [Hash]
  # @param chunk_size [Integer]
  # @return [Array<Hash>]
  def split_large_hash(original_hash, chunk_size: 100)
    raise HashUtilError, "chunk_size must be greater than 0" if chunk_size <= 0

    items = original_hash.to_a # Ruby Hash preserves insertion order
    chunks = []

    items.each_slice(chunk_size) do |slice|
      chunks << slice.to_h
    end

    chunks
  end
end

# -------------------------
# Quick examples (optional)
# -------------------------
# puts HashUtil.hash_string("hello", length: 32)
#
# data = { "a" => { "b" => { "c" => 42 } } }
# p HashUtil.dig_nested_hash(data, ["a", "b", "c"]) # => 42
# p HashUtil.dig_nested_hash(data, ["a", "b", "c"], delete: true) # => 42
# p data # => {"a"=>{"b"=>{}}}
#
# dic = {}
# HashUtil.set_nested_hash(dic, ["a", "b", "c"], 42)
# p dic # => {"a"=>{"b"=>{"c"=>42}}}
#
# dic2 = { "a" => { "b" => { "c" => 42 } }, "x" => nil }
# p HashUtil.flatten_nested_hash(dic2, splitter: ".") # => {"a.b.c"=>42, "x"=>nil}
#
# dic3 = { "a" => { "b" => { "c" => 42 } }, "x" => 21 }
# HashUtil.map_nested_hash(dic3) { |_path, v| v * 2 }
# p dic3 # => {"a"=>{"b"=>{"c"=>84}}, "x"=>42}
#
# long_hash = (0...250).to_h { |i| ["key#{i}", i] }
# chunks = HashUtil.split_large_hash(long_hash, chunk_size: 100)
# p chunks.length # => 3
# p chunks[0]["key99"] # => 99
# p chunks[1]["key100"] # => 100