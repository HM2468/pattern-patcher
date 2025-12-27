# frozen_string_literal: true

module Support
  module FileByteOffsets
    module_function

    REPLACEMENT_CHAR = "�"

    def normalize_utf8(content)
      s = content.to_s.dup
      s.force_encoding(Encoding::UTF_8)
      s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: REPLACEMENT_CHAR)
    end

    def build(content)
      Mapper.new(normalize_utf8(content))
    end

    def replace(origin_content:, replaced_content:, byte_start:, byte_end:)
      origin = normalize_utf8(origin_content)
      replacement = normalize_utf8(replaced_content)

      bs = byte_start.to_i
      be = byte_end.to_i

      raise ArgumentError, "byte_start must be >= 0" if bs < 0
      raise ArgumentError, "byte_end must be >= byte_start" if be < bs
      raise ArgumentError, "byte_end out of range" if be > origin.bytesize

      prefix = origin.byteslice(0, bs) || +""
      suffix = origin.byteslice(be, origin.bytesize - be) || +""

      (prefix.b + replacement.b + suffix.b).force_encoding(Encoding::UTF_8)
    end

    class Mapper
      attr_reader :content, :lines

      def initialize(normalized_content)
        @content = normalized_content
        @lines = @content.lines
        build_char_to_byte!
        build_line_char_starts!
      end

      def char_to_byte(char_index)
        i = char_index.to_i
        return 0 if i <= 0
        return @char_to_byte[-1] if i >= @char_to_byte.length
        @char_to_byte[i]
      end

      def locate_line_and_char(start_char, end_char)
        sc = start_char.to_i
        ec = end_char.to_i

        line_idx = find_line_index_for_char(sc)
        line_start_char = @line_char_starts[line_idx]
        line_at = line_idx + 1

        [line_at, sc - line_start_char, ec - line_start_char]
      end

      def line_text(line_at)
        @lines[line_at.to_i - 1].to_s
      end

      private

      def build_char_to_byte!
        @char_to_byte = [0]
        bytes = 0
        @content.each_char do |ch|
          bytes += ch.bytesize
          @char_to_byte << bytes
        end
      end

      def build_line_char_starts!
        @line_char_starts = []
        pos = 0
        @lines.each do |ln|
          @line_char_starts << pos
          pos += ln.each_char.count
        end
        @line_char_starts << pos
      end

      def find_line_index_for_char(char_index)
        lo = 0
        hi = @line_char_starts.length - 2
        while lo <= hi
          mid = (lo + hi) / 2
          if @line_char_starts[mid] <= char_index && char_index < @line_char_starts[mid + 1]
            return mid
          elsif char_index < @line_char_starts[mid]
            hi = mid - 1
          else
            lo = mid + 1
          end
        end
        @line_char_starts.length - 2
      end
    end
  end
end