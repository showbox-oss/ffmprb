module Ffmprb

  module Filter

    class Error < Ffmprb::Error; end

    class << self

      attr_accessor :silence_noise_max_db

      def alphamerge(inputs, output=nil)
        inout "alphamerge", inputs, output
      end

      def afade_in(duration, input=nil, output=nil)
        inout "afade=in:d=%{duration}:curve=hsin", input, output, duration: duration
      end

      def afade_out(duration, input=nil, output=nil)
        inout "afade=out:d=%{duration}:curve=hsin", input, output, duration: duration
      end

      def amix_to_first_same_volume(inputs, output=nil)
        filters = []
        new_inputs = inputs.map do |input|
          if input == inputs.first
            input
          else
            "apd#{input}".tap do |lbl_aux|
              filters +=
                inout("apad", input, lbl_aux)  # NOTE we'll see if we really need this filter separate
            end
          end
        end
        filters +
          inout("amix=%{inputs_count}:duration=shortest:dropout_transition=0, volume=%{inputs_count}",
            new_inputs, output, inputs_count: (inputs.empty?? nil : inputs.size))
      end

      def anull(input=nil, output=nil)
        inout "anull", input, output
      end

      def anullsink(input=nil)
        inout "anullsink", input, nil
      end

      def asplit(inputs=nil, outputs=nil)
        inout "asplit", inputs, outputs
      end

      def atrim(st, en=nil, input=nil, output=nil)
        inout "atrim=%{start_end}, asetpts=PTS-STARTPTS", input, output,
          start_end: [st, en].compact.join(':')
      end

      def blank_source(duration, resolution, fps, output=nil)
        color_source '0x000000@0', duration, resolution, fps, output
      end

      def color_source(color, duration, resolution, fps, output=nil)
        inout "color=%{color}:d=%{duration}:s=%{resolution}:r=%{fps}", nil, output,
          color: color, duration: duration, resolution: resolution, fps: fps
      end

      def fade_out_alpha(duration, input=nil, output=nil)
        inout "fade=out:d=%{duration}:alpha=1", input, output, duration: duration
      end

      def fps(fps, input=nil, output=nil)
        inout "fps=fps=%{fps}", input, output, fps: fps
      end

      def concat_v(inputs, output=nil)
        inout "concat=%{inputs_count}:v=1:a=0", inputs, output,
          inputs_count: (inputs.empty?? nil : inputs.size)
      end

      def concat_a(inputs, output=nil)
        inout "concat=%{inputs_count}:v=0:a=1", inputs, output,
          inputs_count: (inputs.empty?? nil : inputs.size)
      end

      def concat_av(inputs, output=nil)
        inout "concat=%{inputs_count}:v=1:a=1", inputs, output,
          inputs_count: (inputs.empty? || inputs.size % 2 != 0 ? nil : inputs.size/2)  # XXX meh
      end

      def copy(input=nil, output=nil)
        inout "copy", input, output
      end

      # TODO unused at the moment
      def crop(crop, input=nil, output=nil)
        inout "crop=x=%{left}:y=%{top}:w=%{width}:h=%{height}", input, output, crop
      end

      def crop_prop(crop, input=nil, output=nil)
        inout "crop=%{crop_exp}", input, output,
          crop_exp: crop_prop_exps(crop).join(':')
      end

      def crop_prop_exps(crop)
        exps = []

        if crop[:left]
          exps << "x=in_w*#{crop[:left]}"
        end

        if crop[:top]
          exps << "y=in_h*#{crop[:top]}"
        end

        if crop[:right] && crop[:left]
          fail Error, "Must specify two of {left, right, width} at most"  if crop[:width]
          crop[:width] = 1 - crop[:right] - crop[:left]
        elsif crop[:width]
          if !crop[:left] && crop[:right]
            crop[:left] = 1 - crop[:width] - crop[:right]
            exps << "x=in_w*#{crop[:left]}"
          end
        end
        exps << "w=in_w*#{crop[:width]}"

        if crop[:bottom] && crop[:top]
          fail Error, "Must specify two of {top, bottom, height} at most"  if crop[:height]
          crop[:height] = 1 - crop[:bottom] - crop[:top]
        elsif crop[:height]
          if !crop[:top] && crop[:bottom]
            crop[:top] = 1 - crop[:height] - crop[:bottom]
            exps << "y=in_h*#{crop[:top]}"
          end
        end
        exps << "h=in_h*#{crop[:height]}"

        exps
      end

      # NOTE might be very useful with UGC: def cropdetect

      def nullsink(input=nil)
        inout "nullsink", input, nil
      end

      def overlay(x=0, y=0, inputs=nil, output=nil)
        inout "overlay=x=%{x}:y=%{y}:eof_action=pass", inputs, output, x: x, y: y
      end

      def pad(resolution, input=nil, output=nil)
        width, height = resolution.to_s.split('x')
        inout [
          inout("pad=%{width}:%{height}:(%{width}-iw*min(%{width}/iw\\,%{height}/ih))/2:(%{height}-ih*min(%{width}/iw\\,%{height}/ih))/2",
            width: width, height: height),
          *setsar(1)  # NOTE the scale & pad formulae damage SAR a little, unfortunately
        ].join(', '), input, output
      end

      def setsar(ratio, input=nil, output=nil)
        inout "setsar=%{ratio}", input, output, ratio: ratio
      end

      def scale(resolution, input=nil, output=nil)
        width, height = resolution.to_s.split('x')
        inout [
          inout("scale=iw*min(%{width}/iw\\,%{height}/ih):ih*min(%{width}/iw\\,%{height}/ih)", width: width, height: height),
          *setsar(1)  # NOTE the scale & pad formulae damage SAR a little, unfortunately
        ].join(', '), input, output
      end

      def scale_pad(resolution, input=nil, output=nil)
        inout [
          *scale(resolution),
          *pad(resolution)
        ].join(', '), input, output
      end

      def scale_pad_fps(resolution, _fps, input=nil, output=nil)
        inout [
          *scale_pad(resolution),
          *fps(_fps)
        ].join(', '), input, output
      end

      def silencedetect(input=nil, output=nil)
        inout "silencedetect=d=1:n=%{silence_noise_max_db}dB", input, output,
          silence_noise_max_db: silence_noise_max_db
      end

      def silent_source(duration, output=nil)
        inout "aevalsrc=0:d=%{duration}", nil, output, duration: duration
      end

      # NOTE might be very useful with transitions: def smartblur

      def split(inputs=nil, outputs=nil)
        inout "split", inputs, outputs
      end

      def blend_v(duration, resolution, fps, inputs, output=nil)
        fail Error, "must be given 2 inputs"  unless inputs.size == 2

        aux_lbl = "blnd#{inputs[0]}"
        auxx_lbl = "x#{aux_lbl}"
        [
          *white_source(duration, resolution, fps, aux_lbl),
          *inout([
            *alphamerge([inputs[0], aux_lbl]),
            *fade_out_alpha(duration)
          ].join(', '), nil, auxx_lbl),
          *overlay(0, 0, [inputs[1], auxx_lbl], output),
        ]
      end

      def blend_a(duration, inputs, output=nil)
        fail Error, "must be given 2 inputs"  unless inputs.size == 2

        aux_lbl = "blnd#{inputs[0]}"
        auxx_lbl = "x#{aux_lbl}"
        [
          *afade_out(duration, inputs[0], aux_lbl),
          *afade_in(duration, inputs[1], auxx_lbl),
          *amix_to_first_same_volume([auxx_lbl, aux_lbl], output)
        ]
      end

      def trim(st, en=nil, input=nil, output=nil)
        inout "trim=%{start_end}, setpts=PTS-STARTPTS", input, output,
          start_end: [st, en].compact.join(':')
      end

      def volume(volume, input=nil, output=nil)
        inout "volume='%{volume_exp}':eval=frame", input, output,
          volume_exp: volume_exp(volume)
      end

      def volume_exp(volume)
        return volume  unless volume.is_a?(Hash)

        fail Error, "volume cannot be empty"  if volume.empty?

        prev_at = 0.0
        prev_vol = volume[prev_at] || 1.0
        exp = "#{volume[volume.keys.last]}"
        volume.each do |at, vol|
          next if at == prev_at
          vol_exp =
            if (vol - prev_vol).abs < 0.001
              vol
            else
              "(#{vol - prev_vol}*t + #{prev_vol*at - vol*prev_at})/#{at - prev_at}"
            end
          exp = "if(between(t, #{prev_at}, #{at}), #{vol_exp}, #{exp})"
          prev_at = at
          prev_vol = vol
        end
        exp
      end

      def white_source(duration, resolution, fps, output=nil)
        color_source '0xFFFFFF@1', duration, resolution, fps, output
      end

      def complex_options(*filters)
        ['-filter_complex', filters.join('; ')]  unless filters.empty?
      end

      private

      def inout(filter, inputs=nil, outputs=nil, **values)
        values.each do |key, value|
          fail Error, "#{filter} needs #{key}"  if value.to_s.empty?
        end
        filter = filter % values
        filter = "#{[*inputs].map{|s| "[#{s}]"}.join ' '} " + filter  if inputs
        filter = filter + " #{[*outputs].map{|s| "[#{s}]"}.join ' '}"  if outputs
        [filter]
      end

    end

  end

end
