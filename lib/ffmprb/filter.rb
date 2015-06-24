module Ffmprb

  module Filter

    class << self

      def atrim(st, en, input=nil, output=nil)
        inout "atrim=#{[st, en].compact.join ':'}, asetpts=PTS-STARTPTS", input, output
      end

      def amix(inputs, output=nil)
        inout "amix=#{[*inputs].length}", inputs, output
      end

      def black_source(duration, output=nil)
        inout "color=black:d=#{duration}", nil, output
      end

      def concat_v(inputs, output=nil)
        inout "concat=#{[*inputs].length}:v=1:a=0", inputs, output
      end

      def concat_a(inputs, output=nil)
        inout "concat=#{[*inputs].length}:v=0:a=1", inputs, output
      end

      def concat_av(inputs, output=nil)
        inout "concat=#{inputs.length/2}:v=1:a=1", inputs, output
      end

      def copy(input=nil, output=nil)
        inout "copy", input, output
      end

      def crop(crop, input=nil, output=nil)
        inout "crop=#{crop_exps(crop).join ':'}", input, output
      end

      def crop_exps(crop)
        exps = []

        if crop[:left] > 0
          exps << "x=in_w*#{crop[:left]}"
        end

        if crop[:top] > 0
          exps << "y=in_h*#{crop[:top]}"
        end

        if crop[:right] > 0 && crop[:left]
          raise Error.new "Must specify two of {left, right, width} at most"  if crop[:width]
          crop[:width] = 1 - crop[:right] - crop[:left]
        elsif crop[:width] > 0
          if !crop[:left] && crop[:right] > 0
            crop[:left] = 1 - crop[:width] - crop[:right]
            exps << "x=in_w*#{crop[:left]}"
          end
        end
        exps << "w=in_w*#{crop[:width]}"

        if crop[:bottom] > 0 && crop[:top]
          raise Error.new "Must specify two of {top, bottom, height} at most"  if crop[:height]
          crop[:height] = 1 - crop[:bottom] - crop[:top]
        elsif crop[:height] > 0
          if !crop[:top] && crop[:bottom] > 0
            crop[:top] = 1 - crop[:height] - crop[:bottom]
            exps << "y=in_h*#{crop[:top]}"
          end
        end
        exps << "h=in_h*#{crop[:height]}"

        exps
      end

      def pad(w, h, input=nil, output=nil)
        inout "pad=#{w}:#{h}:(#{w}-iw*min(#{w}/iw\\,#{h}/ih))/2:(#{h}-ih*min(#{w}/iw\\,#{h}/ih))/2", input, output
      end

      def scale(w, h, input=nil, output=nil)
        inout "scale=iw*min(#{w}/iw\\,#{h}/ih):ih*min(#{w}/iw\\,#{h}/ih)", input, output
      end

      def silent_source(duration, output=nil)
        inout "aevalsrc=0:d=#{duration}", nil, output
      end

      def scale_pad(w, h, input=nil, output=nil)
        inout [scale(w, h), pad(w, h)].join(', '), input, output
      end

      def trim(st, en, input=nil, output=nil)
        inout "trim=#{[st, en].compact.join ':'}, setpts=PTS-STARTPTS", input, output
      end

      def complex_options(filters)
        if filters.empty?
          ''
        else
          " -filter_complex '#{filters.join '; '}'"
        end
      end

      private

      def inout(filter, inputs, outputs)
        filter.tap do |f|
          f.prepend "#{[*inputs].map{|s| "[#{s}]"}.join ' '} "  if inputs
          f << " #{[*outputs].map{|s| "[#{s}]"}.join ' '}"  if outputs
        end
      end

    end

  end

end
