# coding: utf-8

class PDF::Reader
  class PdfObject
    # Serializes Ruby objects to their PDF equivalents.  Most primitive objects
    # will work as expected, but please note that Name objects are represented
    # by Ruby Symbol objects and Dictionary objects are represented by Ruby hashes
    # (keyed by symbols)
    #
    #  Examples:
    #
    #     PdfObject.dump(true)      #=> "true"
    #     PdfObject.dump(false)     #=> "false"
    #     PdfObject.dump(1.2124)    #=> "1.2124"
    #     PdfObject.dump("foo bar") #=> "(foo bar)"
    #     PdfObject.dump(:Symbol)   #=> "/Symbol"
    #     PdfObject.dump(["foo",:bar, [1,2]]) #=> "[foo /bar [1 2]]"
    #
    def self.dump(obj, in_content_stream = false)
      case(obj)
      when NilClass   then "null"
      when TrueClass  then "true"
      when FalseClass then "false"
      when Numeric
        if (str = String(obj)) =~ /e/i
          # scientific notation is not supported in PDF
          sprintf("%.16f", obj).gsub(/\.?0+\z/, "")
        else
          str
        end
      when Array
        "[" << obj.map { |e| PdfObject.dump(e, in_content_stream) }.join(' ') << "]"
      when Time
        obj = obj.strftime("D:%Y%m%d%H%M%S%z").chop.chop + "'00'"
        obj = obj.gsub(/[\\\n\r\t\b\f\(\)]/n) { |m| "\\#{m}" }
        "(#{obj})"
      when String
        obj = utf8_to_utf16(obj) unless in_content_stream
        "<" << string_to_hex(obj) << ">"
       when Symbol
         "/" + obj.to_s.unpack("C*").map { |n|
          if n < 33 || n > 126 || [35,40,41,47,60,62].include?(n)
            "#" + n.to_s(16).upcase
          else
            [n].pack("C*")
          end
         }.join
      when Hash
        output = "<< "
        obj.each do |k,v|
          unless String === k || Symbol === k
            raise "A PDF Dictionary must be keyed by names"
          end
          output << PdfObject.dump(k.to_sym, in_content_stream) << " " <<
                    PdfObject.dump(v, in_content_stream) << "\n"
        end
        output << ">>"
      when PDF::Reader::Reference
        "#{obj.id} #{obj.gen} R"
      else
        raise "This object cannot be serialized to PDF (#{obj.inspect})"
      end

    end

    if "".respond_to?(:encode)
      # Ruby 1.9+
      def self.utf8_to_utf16(str)
        utf16 = "\xFE\xFF".force_encoding("UTF-16BE") + str.encode("UTF-16BE")
      end

      # encodes any string into a hex representation. The result is a string
      # with only 0-9 and a-f characters. That result is valid ASCII so tag
      # it as such to account for behaviour of different ruby VMs
      def self.string_to_hex(str)
        str.unpack("H*").first.force_encoding("ascii")
      end
    else
      # Ruby 1.8
      def self.utf8_to_utf16(str)
        utf16 = "\xFE\xFF"

        str.codepoints do |cp|
          if cp < 0x10000 # Basic Multilingual Plane
            utf16 << [cp].pack("n")
          else
            # pull out high/low 10 bits
            hi, lo = (cp - 0x10000).divmod(2**10)
            # encode a surrogate pair
            utf16 << [0xD800 + hi, 0xDC00 + lo].pack("n*")
          end
        end

        utf16
      end

      def self.string_to_hex(str)
        str.unpack("H*").first
      end
    end
  end
end