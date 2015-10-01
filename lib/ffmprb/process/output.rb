module Ffmprb

  class Process

    class Output

      def initialize(io, only:, resolution:, fps:)
        @io = resolve(io)
        @channels = [*only]
        @channels = nil  if @channels.empty?
        @resolution = resolution
        @fps = 30
      end

      # XXX This method is exceptionally long at the moment. This is not too grand.
      # However, structuring the code should be undertaken with care, as not to harm the composition clarity.
      def options_for(process)  # NOTE process is not thread-safe (nothing actually is), so must not share it with another thread
        fail Error, "Nothing to roll..."  unless @reels
        fail Error, "Supporting just full_screen for now, sorry."  unless @reels.all?(&:full_screen?)

        filters = []

        # Concatting
        segments = []

        @reels.each_with_index do |curr_reel, i|

          lbl = nil

          if curr_reel.reel

            # NOTE mapping input to this lbl

            lbl = "rl#{i}"
            lbl_aux = "sp#{i}"

            # NOTE Image-Scaling & Image-Padding to match the target resolution
            # XXX full screen only (see exception above)

            filters.concat(  # XXX an opportunity for optimisation through passing the actual channel options
              curr_reel.reel.filters_for lbl_aux, process: process, output: self, video: channel?(:video), audio: channel?(:audio)
            )
            filters.concat(
              Filter.scale_pad_fps target_width, target_height, target_fps, "#{lbl_aux}:v", "#{lbl}:v"
            )  if channel?(:video)
            filters.concat(
              Filter.anull "#{lbl_aux}:a", "#{lbl}:a"
            )  if channel?(:audio)
          end

          trim_prev_at = curr_reel.after || (curr_reel.transition && 0)

          if trim_prev_at

            # NOTE make sure previous reel rolls _long_ enough AND then _just_ enough

            prev_lbl = segments.pop

            lbl_pad = "bl#{prev_lbl}#{i}"
            # NOTE generously padding the previous segment to support for all the cases
            filters.concat(
              Filter.blank_source trim_prev_at + curr_reel.transition_length, target_resolution, target_fps, "#{lbl_pad}:v"
            )  if channel?(:video)
            filters.concat(
              Filter.silent_source trim_prev_at + curr_reel.transition_length, "#{lbl_pad}:a"
            )  if channel?(:audio)

            if prev_lbl
              lbl_aux = lbl_pad
              lbl_pad = "pd#{prev_lbl}#{i}"
              filters.concat(
                Filter.concat_v ["#{prev_lbl}:v", "#{lbl_aux}:v"], "#{lbl_pad}:v"
              )  if channel?(:video)
              filters.concat(
                Filter.concat_a ["#{prev_lbl}:a", "#{lbl_aux}:a"], "#{lbl_pad}:a"
              )  if channel?(:audio)
            end

            if curr_reel.transition

              # NOTE Split the previous segment for transition

              if trim_prev_at > 0
                filters.concat(
                  Filter.split "#{lbl_pad}:v", ["#{lbl_pad}a:v", "#{lbl_pad}b:v"]
                )  if channel?(:video)
                filters.concat(
                  Filter.asplit "#{lbl_pad}:a", ["#{lbl_pad}a:a", "#{lbl_pad}b:a"]
                )  if channel?(:audio)
                lbl_pad, lbl_pad_ = "#{lbl_pad}a", "#{lbl_pad}b"
              else
                lbl_pad, lbl_pad_ = nil, lbl_pad
              end
            end

            if lbl_pad

              # NOTE Trim the previous segment finally

              new_prev_lbl = "tm#{prev_lbl}#{i}a"

              filters.concat(
                Filter.trim 0, trim_prev_at, "#{lbl_pad}:v", "#{new_prev_lbl}:v"
              )  if channel?(:video)
              filters.concat(
                Filter.atrim 0, trim_prev_at, "#{lbl_pad}:a", "#{new_prev_lbl}:a"
              )  if channel?(:audio)

              segments << new_prev_lbl
              Ffmprb.logger.debug "Concatting segments: #{new_prev_lbl} pushed"
            end

            if curr_reel.transition

              # NOTE snip the end of the previous segment and combine with this reel

              lbl_end1 = "tm#{i}b"
              lbl_reel = "tn#{i}"
              if !lbl  # no reel
                lbl_aux = "bk#{i}"
                filters.concat(
                  Filter.blank_source curr_reel.transition_length, target_resolution, channel(:video).fps, "#{lbl_aux}:v"
                )  if channel?(:video)
                filters.concat(
                  Filter.silent_source curr_reel.transition_length, "#{lbl_aux}:a"
                )  if channel?(:audio)
              end  # NOTE else hope lbl is long enough for the transition
              filters.concat(
                Filter.trim trim_prev_at, trim_prev_at + curr_reel.transition_length, "#{lbl_pad_}:v", "#{lbl_end1}:v"
              )  if channel?(:video)
              filters.concat(
                Filter.atrim trim_prev_at, trim_prev_at + curr_reel.transition_length, "#{lbl_pad_}:a", "#{lbl_end1}:a"
              )  if channel?(:audio)
              filters.concat(
                Filter.transition_av curr_reel.transition, target_resolution, target_fps, [lbl_end1, lbl || lbl_aux], lbl_reel,
                  video: channel?(:video), audio: channel?(:audio)
              )
              lbl = lbl_reel
            end

          end

          segments << lbl  # NOTE can be nil
        end

        segments.compact!

        lbl_out = 'oo'

        filters.concat(
          Filter.concat_v segments.map{|s| "#{s}:v"}, "#{lbl_out}:v"
        )  if channel?(:video)
        filters.concat(
          Filter.concat_a segments.map{|s| "#{s}:a"}, "#{lbl_out}:a"
        )  if channel?(:audio)

        # Overlays

        # NOTE in-process overlays first

        @overlays.to_a.each_with_index do |over_reel, i|
          next  if over_reel.duck  # XXX this is currently a single case of multi-process... process

          fail Error, "Video overlays are not implemented just yet, sorry..."  if over_reel.reel.channel?(:video)

          # Audio overlaying

          lbl_nxt = "oo#{i}"

          lbl_over = "ol#{i}"
          filters.concat(  # NOTE audio only, see above
            over_reel.reel.filters_for lbl_over, process: process, output: self
          )
          filters.concat(
            Filter.copy "#{lbl_out}:v", "#{lbl_nxt}:v"
          )  if channel?(:video)
          filters.concat(
            Filter.amix_to_first_same_volume ["#{lbl_out}:a", "#{lbl_over}:a"], "#{lbl_nxt}:a"
          )  if channel?(:audio)

          lbl_out = lbl_nxt
        end

        # NOTE multi-process overlays last

        channel_lbl_ios = {}  # XXX this is a spaghetti machine
        channel_lbl_ios["#{lbl_out}:v"] = @io  if channel?(:video)
        channel_lbl_ios["#{lbl_out}:a"] = @io  if channel?(:audio)

        # XXX supporting just "full" overlays for now, see exception in #add_reel
        @overlays.to_a.each_with_index do |over_reel, i|

          # XXX this is currently a single case of multi-process... process
          if over_reel.duck
            fail Error, "Don't know how to duck video... yet"  if over_reel.duck != :audio

            # So ducking just audio here, ye?

            main_a_o = channel_lbl_ios["#{lbl_out}:a"]
            fail Error, "Main output does not contain audio to duck"  unless main_a_o
            # XXX#181845 must really seperate channels for streaming (e.g. mp4 wouldn't stream through the fifo)
            main_a_inter_o = File.temp_fifo(main_a_o.extname)
            channel_lbl_ios.each do |channel_lbl, io|
              channel_lbl_ios[channel_lbl] = main_a_inter_o  if io == main_a_o  # XXX ~~~spaghetti
            end
            Ffmprb.logger.debug "Re-routed the main audio output (#{main_a_inter_o.path}->...->#{main_a_o.path}) through the process of audio ducking"

            overlay_i, overlay_o = File.threaded_buffered_fifo(Process.intermediate_channel_extname :audio)
            lbl_over = "ol#{i}"
            filters.concat(
              over_reel.reel.filters_for lbl_over, process: process, output: self, video: false, audio: true
            )
            channel_lbl_ios["#{lbl_over}:a"] = overlay_i
            Ffmprb.logger.debug "Routed and buffering an auxiliary output fifos (#{overlay_i.path}>#{overlay_o.path}) for overlay"

            inter_i, inter_o = File.threaded_buffered_fifo(main_a_inter_o.extname)
            Ffmprb.logger.debug "Allocated fifos to buffer media (#{inter_i.path}>#{inter_o.path}) while finding silence"

            Util::Thread.new "audio ducking" do
              silence = Ffmprb.find_silence(main_a_inter_o, inter_i)

              Ffmprb.logger.debug "Audio ducking with silence: [#{silence.map{|s| "#{s.start_at}-#{s.end_at}"}.join ', '}]"

              Process.duck_audio inter_o, overlay_o, silence, main_a_o,
                video: (channel?(:video)? {resolution: target_resolution, fps: target_fps}: false)
            end
          end

        end

        Filter.complex_options(filters).tap do |options|

          io_channel_lbls = {}  # XXX ~~~spaghetti
          channel_lbl_ios.each do |channel_lbl, io|
            (io_channel_lbls[io] ||= []) << channel_lbl
          end
          io_channel_lbls.each do |io, channel_lbls|
            channel_lbls.each do |channel_lbl|
              options << '-map' << "[#{channel_lbl}]"
              # XXX temporary patchwork
              options << '-c:a' << 'libmp3lame'  if channel_lbl =~ /:a$/
            end
            options << io.path
          end

        end
      end

      def roll(
        reel,
        onto: :full_screen,
        after: nil,
        transition: nil
      )
        fail Error, "Nothing to roll..."  unless reel
        fail Error, "Supporting :transition with :after only at the moment, sorry."  unless
          !transition || after || @reels.to_a.empty?

        add_reel reel, after, transition, (onto == :full_screen)
      end
      alias :lay :roll

      def overlay(
        reel,
        at: 0,
        transition: nil,
        duck: nil
      )
        fail Error, "Nothing to overlay..."  unless reel
        fail Error, "Nothing to lay over yet..."  if @reels.to_a.empty?
        fail Error, "Ducking overlays should come last... for now"  if !duck && @overlays.to_a.last && @overlays.to_a.last.duck

        (@overlays ||= []) <<
          OpenStruct.new(reel: reel, at: at, duck: duck)
      end

      def channel?(medium)
        @channels.include?(medium) && @io.channel?(medium) && reels_channel?(medium)
      end

      def channel?(medium, force=false)
        return !!@channels && @channels.include?(medium) && @io.channel?(medium)  if force

        (!@channels || @channels.include?(medium)) && @io.channel?(medium) &&
          reels_channel?(medium)
      end

      # XXX TMP protected

      def resolve(io)
        return io  unless io.is_a? String

        case io
        when /^\/\w/
          File.create(io).tap do |file|
            Ffmprb.logger.warn "Output file exists (#{file.path}), will probably overwrite"  if file.exist?
          end
        else
          fail Error, "Cannot resolve output: #{io}"
        end
      end

      # XXX TMP private

      def reels_channel?(medium)
        @reels.to_a.all?{|r| !r.reel || r.reel.channel?(medium)}
      end

      def add_reel(reel, after, transition, full_screen)
        fail Error, "No time to roll..."  if after && after.to_f <= 0
        fail Error, "Partial (not coming last in process) overlays are currently unsupported, sorry."  unless @overlays.to_a.empty?

        # NOTE limited functionality (see exception in Filter.transition_av): transition = {effect => duration}
        transition_length = transition.to_h.max_by{|k,v| v}.to_a.last.to_f

        (@reels ||= []) <<
          OpenStruct.new(reel: reel, after: after, transition: transition, transition_length: transition_length, full_screen?: full_screen)
      end

      def target_width
        @target_width ||= @resolution.to_s.split('x')[0].to_i.tap do |width|
          raise Error, "Width (#{width}) must be divisible by 2, sorry"  unless width % 2 == 0
        end
      end
      def target_height
        @target_height ||= @resolution.to_s.split('x')[1].to_i.tap do |height|
          raise Error, "Height (#{height}) must be divisible by 2, sorry"  unless height % 2 == 0
        end
      end
      def target_resolution
        "#{target_width}x#{target_height}"
      end

      def target_fps
        @fps
      end

    end

  end

end
