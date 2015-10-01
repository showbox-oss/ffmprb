module Ffmprb

  module Filter

    class << self

      attr_accessor :silence_noise_max_db

      def alphamerge(inputs, output=nil)
        inout "alphamerge", inputs, output
      end

      def afade_in(duration=1, input=nil, output=nil)
        inout "afade=in:d=#{duration}:curve=hsin", input, output
      end

      def afade_out(duration=1, input=nil, output=nil)
        inout "afade=out:d=#{duration}:curve=hsin", input, output
      end

      def amix_to_first_same_volume(inputs, output=nil)
        filters = []
        new_inputs = inputs.map do |input|
          if input == inputs.first
            input
          else
            "apd#{input}".tap do |lbl_aux|
              filters.concat inout('apad', input, lbl_aux)
            end
          end
        end
        filters +
          inout("amix=#{inputs.length}:duration=shortest:dropout_transition=0, volume=#{inputs.length}", new_inputs, output)
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

      def atrim(st, en, input=nil, output=nil)
        inout "atrim=#{[st, en].compact.join ':'}, asetpts=PTS-STARTPTS", input, output
      end

      def blank_source(duration, resolution, fps, output=nil)
        color_source '0x000000@0', duration, resolution, fps, output
      end

      def color_source(color, duration, resolution, fps, output=nil)
        filter = "color=#{color}"
        filter << ":d=#{duration}"
        filter << ":s=#{resolution}"
        filter << ":r=#{fps}"
        inout filter, nil, output
      end

      def fade_out_alpha(duration=1, input=nil, output=nil)
        inout "fade=out:d=#{duration}:alpha=1", input, output
      end

      def fps(fps, input=nil, output=nil)
        inout "fps=fps=#{fps}", input, output
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

      # XXX might be very useful with UGC: def cropdetect

      def nullsink(input=nil)
        inout "nullsink", input, nil
      end

      def overlay(x=0, y=0, inputs=nil, output=nil)
        inout "overlay=x=#{x}:y=#{y}:eof_action=pass", inputs, output
      end

      def pad(width, height, input=nil, output=nil)
        inout "pad=#{width}:#{height}:(#{width}-iw*min(#{width}/iw\\,#{height}/ih))/2:(#{height}-ih*min(#{width}/iw\\,#{height}/ih))/2", input, output
      end

      def setsar(ratio, input=nil, output=nil)
        inout "setsar=#{ratio}", input, output
      end

      def scale(width, height, input=nil, output=nil)
        inout "scale=iw*min(#{width}/iw\\,#{height}/ih):ih*min(#{width}/iw\\,#{height}/ih)", input, output
      end

      def scale_pad_fps(width, height, _fps, input=nil, output=nil)
        inout [
          *scale(width, height),
          *pad(width, height),
          *setsar(1),  # NOTE the scale & pad formulae damage SAR a little, unfortunately
          *fps(_fps)
        ].join(', '), input, output
      end

      def silencedetect(input=nil, output=nil)
        inout "silencedetect=d=1:n=#{silence_noise_max_db}dB", input, output
      end

      def silent_source(duration, output=nil)
        inout "aevalsrc=0:d=#{duration}", nil, output
      end

      # XXX might be very useful with transitions: def smartblur

      def split(inputs=nil, outputs=nil)
        inout "split", inputs, outputs
      end

      def transition_av(transition, resolution, fps, inputs, output=nil, video: true, audio: true)
        blend_duration = transition[:blend].to_f
        fail "Unsupported (yet) transition, sorry."  unless
          transition.size == 1 && blend_duration > 0

        aux_lbl = "rn#{inputs.object_id}"  # should be sufficiently random
        auxx_lbl = "x#{aux_lbl}"
        [].tap do |filters|
          filters.concat [
            *white_source(blend_duration, resolution, fps, "#{aux_lbl}:v"),
            *inout([
              *alphamerge(["#{inputs.first}:v", "#{aux_lbl}:v"]),
              *fade_out_alpha(blend_duration)
            ].join(', '), nil, "#{auxx_lbl}:v"),
            *overlay(0, 0, ["#{inputs.last}:v", "#{auxx_lbl}:v"], "#{output}:v"),
          ]  if video
          filters.concat [
            *afade_out(blend_duration, "#{inputs.first}:a", "#{aux_lbl}:a"),
            *afade_in(blend_duration, "#{inputs.last}:a", "#{auxx_lbl}:a"),
            *amix_to_first_same_volume(["#{auxx_lbl}:a", "#{aux_lbl}:a"], "#{output}:a")
          ]  if audio
        end
      end

      def trim(st, en, input=nil, output=nil)
        inout "trim=#{[st, en].compact.join ':'}, setpts=PTS-STARTPTS", input, output
      end

      def volume(volume, input=nil, output=nil)
        inout "volume='#{volume_exp volume}':eval=frame", input, output
      end

      def volume_exp(volume)
        return volume  unless volume.is_a?(Hash)

        fail Error, "volume cannot be empty"  if volume.empty?

        prev_at = 0.0
        prev_vol = volume[prev_at] || 1.0
        exp = "#{volume[volume.keys.last]}"
        volume.each do |at, vol|
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

      def inout(filter, inputs, outputs)
        [
          filter.tap do |f|
            f.prepend "#{[*inputs].map{|s| "[#{s}]"}.join ' '} "  if inputs
            f << " #{[*outputs].map{|s| "[#{s}]"}.join ' '}"  if outputs
          end
        ]
      end

    end

  end

end
