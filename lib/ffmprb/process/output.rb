module Ffmprb

  class Process

    class Output

      def initialize(io, only: nil, resolution: Ffmprb::QVGA, fps: 30)
        @io = io
        @channels = [*only]
        @channels = nil  if @channels.empty?
        @resolution = resolution
        @fps = 30
      end

      def options(process)
        # XXX TODO manage stream labels through process
        raise Error, "Nothing to roll..."  if @reels.select(&:reel).empty?
        raise Error, "Supporting just full_screen for now, sorry."  unless @reels.all?(&:full_screen?)

        filters = []

        # Concatting
        segments = []
        Ffmprb.logger.debug "Concatting segments: start"

        @reels.each_with_index do |curr_reel, i|

          lbl = nil

          if curr_reel.reel

            # NOTE mapping input to this lbl

            lbl = "rl#{i}"
            lbl_aux = "sp#{i}"

            # NOTE Image-Scaling & Image-Padding to match the target resolution
            # XXX full screen only (see exception above)

            filters +=
              curr_reel.reel.filters_for(lbl_aux, process: process,
                video: channel?(:video), audio: channel?(:audio))
            filters +=
              Filter.scale_pad_fps(target_width, target_height, target_fps, "#{lbl_aux}:v", "#{lbl}:v")  if
              channel?(:video)
            filters +=
              Filter.anull("#{lbl_aux}:a", "#{lbl}:a")  if
              channel?(:audio)
          end

          trim_prev_at = curr_reel.after || (curr_reel.transition && 0)

          if trim_prev_at

            # NOTE make sure previous reel rolls _long_ enough AND then _just_ enough

            prev_lbl = segments.pop
            Ffmprb.logger.debug "Concatting segments: #{prev_lbl} popped"

            lbl_pad = "bl#{prev_lbl}#{i}"
            # NOTE generously padding the previous segment to support for all the cases
            filters +=
              Filter.black_source(trim_prev_at + curr_reel.transition_length, target_resolution, target_fps, "#{lbl_pad}:v")  if
              channel?(:video)
            filters +=
              Filter.silent_source(trim_prev_at + curr_reel.transition_length, "#{lbl_pad}:a")  if
              channel?(:audio)

            if prev_lbl
              lbl_aux = lbl_pad
              lbl_pad = "pd#{prev_lbl}#{i}"
              filters +=
                Filter.concat_v(["#{prev_lbl}:v", "#{lbl_aux}:v"], "#{lbl_pad}:v")  if
                channel?(:video)
              filters +=
                Filter.concat_a(["#{prev_lbl}:a", "#{lbl_aux}:a"], "#{lbl_pad}:a")  if
                channel?(:audio)
            end

            if curr_reel.transition

              # NOTE Split the previous segment for transition

              if trim_prev_at > 0
                filters +=
                  Filter.split("#{lbl_pad}:v", ["#{lbl_pad}a:v", "#{lbl_pad}b:v"])  if
                  channel?(:video)
                filters +=
                  Filter.asplit("#{lbl_pad}:a", ["#{lbl_pad}a:a", "#{lbl_pad}b:a"])  if
                  channel?(:audio)
                lbl_pad, lbl_pad_ = "#{lbl_pad}a", "#{lbl_pad}b"
              else
                lbl_pad, lbl_pad_ = nil, lbl_pad
              end
            end

            if lbl_pad

              # NOTE Trim the previous segment finally

              new_prev_lbl = "tm#{prev_lbl}#{i}a"

              filters +=
                Filter.trim(0, trim_prev_at, "#{lbl_pad}:v", "#{new_prev_lbl}:v")  if
                channel?(:video)
              filters +=
                Filter.atrim(0, trim_prev_at, "#{lbl_pad}:a", "#{new_prev_lbl}:a")  if
                channel?(:audio)

              segments << new_prev_lbl
              Ffmprb.logger.debug "Concatting segments: #{new_prev_lbl} pushed"
            end

            if curr_reel.transition

              # NOTE snip the end of the previous segment and combine with this reel

              lbl_end1 = "tm#{i}b"
              lbl_reel = "tn#{i}"
              if !lbl  # no reel
                lbl_aux = "bk#{i}"
                filters +=
                  Filter.black_source(curr_reel.transition_length, target_resolution, target_fps, "#{lbl_aux}:v")  if
                  channel?(:video)
                filters +=
                  Filter.silent_source(curr_reel.transition_length, "#{lbl_aux}:a")  if
                  channel?(:audio)
              end  # NOTE else hope lbl is long enough for the transition
              filters +=
                Filter.trim(trim_prev_at, trim_prev_at + curr_reel.transition_length, "#{lbl_pad_}:v", "#{lbl_end1}:v")  if
                channel?(:video)
              filters +=
                Filter.atrim(trim_prev_at, trim_prev_at + curr_reel.transition_length, "#{lbl_pad_}:a", "#{lbl_end1}:a")  if
                channel?(:audio)
              filters +=
                Filter.transition_av(curr_reel.transition, target_resolution, target_fps, [lbl_end1, lbl || lbl_aux], lbl_reel,
                  video: channel?(:video), audio: channel?(:audio))
              lbl = lbl_reel
            end

          end

          segments << lbl  # NOTE can be nil
          Ffmprb.logger.debug "Concatting segments: #{lbl} pushed"
        end

        segments.compact!

        lbl_out = 'oo'

        filters +=
          Filter.concat_v(segments.map{|s| "#{s}:v"}, "#{lbl_out}:v")  if channel?(:video)
        filters +=
          Filter.concat_a(segments.map{|s| "#{s}:a"}, "#{lbl_out}:a")  if channel?(:audio)

        # Overlays

        # NOTE in-process overlays first

        @overlays.to_a.each_with_index do |over_reel, i|

          # XXX this is currently a single case of multi-process... process
          unless over_reel.duck
            raise Error, "Video overlays are not implemented just yet, sorry..."  if over_reel.reel.channel?(:video)

            # Audio overlaying

            lbl_nxt = "oo#{i}"

            lbl_over = "ol#{i}"
            filters +=
              over_reel.reel.filters_for(lbl_over, process: process)  # NOTE audio only, see above

            filters +=
              Filter.copy("#{lbl_out}:v", "#{lbl_nxt}:v")  if channel?(:video)
            filters +=
              Filter.amix(["#{lbl_out}:a", "#{lbl_over}:a"], "#{lbl_nxt}:a")  if channel?(:audio)

            lbl_out = lbl_nxt
          end

        end

        # NOTE multi-process overlays last

        channel_lbl_ios = {}  # XXX this is a spaghetti machine
        channel_lbl_ios["#{lbl_out}:v"] = @io  if channel?(:video)
        channel_lbl_ios["#{lbl_out}:a"] = @io  if channel?(:audio)

        # XXX supporting just "full" overlays for now, see exception in #add_reel
        @overlays.to_a.each_with_index do |over_reel, i|

          # XXX this is currently a single case of multi-process... process
          if over_reel.duck
            raise Error, "Don't know how to duck video... yet"  if over_reel.duck != :audio

            # So ducking just audio here, ye?

            main_a_o = channel_lbl_ios["#{lbl_out}:a"]
            raise Error, "Main output does not contain audio to duck"  unless main_a_o
            # XXX#181845 must really seperate channels for streaming (e.g. mp4 wouldn't stream through the fifo)
            main_a_inter_o = File.temp_fifo(main_a_o.extname)
            channel_lbl_ios.each do |channel_lbl, io|
              channel_lbl_ios[channel_lbl] = main_a_inter_o  if io == main_a_o  # XXX ~~~spaghetti
            end
            Ffmprb.logger.debug "Re-routed the main audio output (#{main_a_inter_o.path}->...->#{main_a_o.path}) through the process of audio ducking"

            overlay_io = File.buffered_fifo(Process.intermediate_channel_extname :audio)
            process.threaded overlay_io.thr
            lbl_over = "ol#{i}"
            filters +=
              over_reel.reel.filters_for(lbl_over, process: process, video: false, audio: true)
            channel_lbl_ios["#{lbl_over}:a"] = overlay_io.in
            Ffmprb.logger.debug "Routed and buffering an auxiliary output fifos (#{overlay_io.in.path}>#{overlay_io.out.path}) for overlay"

            inter_io = File.buffered_fifo(main_a_inter_o.extname)
            process.threaded inter_io.thr
            Ffmprb.logger.debug "Allocated fifos to buffer media (#{inter_io.in.path}>#{inter_io.out.path}) while finding silence"

            thr = Util::Thread.new "audio ducking" do
              silence = Ffmprb.find_silence(main_a_inter_o, inter_io.in)

              Ffmprb.logger.debug "Audio ducking with silence: [#{silence.map{|s| "#{s.start_at}-#{s.end_at}"}.join ', '}]"

              Process.duck_audio inter_io.out, overlay_io.out, silence, main_a_o,
                video: (channel?(:video)? {resolution: target_resolution, fps: target_fps}: false)
            end
            process.threaded thr
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
            end
            options << io.path
          end

        end
      end

      def cut(
        after: nil,
        transition: nil
      )
        raise Error, "Nothing to cut yet..."  if @reels.empty? || @reels.last.reel.nil?

        add_reel nil, after, transition, @reels.last.full_screen?
      end

      def overlay(
        reel,
        at: 0,
        duck: nil
      )
        raise Error, "Nothing to overlay..."  unless reel
        raise Error, "Nothing to lay over yet..."  if @reels.to_a.empty?
        raise Error, "Ducking overlays should come last... for now"  if !duck && @overlays.to_a.last && @overlays.to_a.last.duck

        (@overlays ||= []) <<
          OpenStruct.new(reel: reel, at: at, duck: duck)
      end

      def roll(
        reel,
        onto: :full_screen,
        after: nil,
        transition: nil
      )
        raise Error, "Nothing to roll..."  unless reel
        raise Error, "Supporting :transition with :after only at the moment, sorry."  unless
          !transition || after || @reels.to_a.empty?

        add_reel reel, after, transition, (onto == :full_screen)
      end

      # XXX? protected

      def channel?(medium, force=false)
        return @channels && @channels.include?(medium)  if force

        (!@channels || @channels.include?(medium)) &&
          reels_channel?(medium)
      end

      private

      def reels_channel?(medium)
        @reels.to_a.all?{|r| !r.reel || r.reel.channel?(medium)}
      end

      def add_reel(reel, after, transition, full_screen)
        raise Error, "No time to roll..."  if after && after.to_f <= 0
        raise Error, "Partial (not coming last in process) overlays are currently unsupported, sorry."  unless @overlays.to_a.empty?

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
