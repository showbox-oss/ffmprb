module Ffmprb

  class Process

    def initialize(*args, &blk)
      @inputs = []
      instance_exec *args, &blk
      run  if blk
    end

    def input(io)
      Input.new(io).tap do |inp|
        @inputs << inp
      end
    end

    def output(io, resolution:, &blk)
      raise Error.new "Just one output for now, sorry."  if @output

      @output = Output.new(io, resolution: resolution, &blk)
    end

    def run
      Ffmprb::Util.ffmpeg command
    end

    def [](obj)
      case obj
      when Input
        @inputs.find_index(obj)
      end
    end

    private

    def command
      input_options + output_options
    end

    def input_options
      @inputs.map(&:options).join
    end

    def output_options
      @output.options self
    end

    class Input

      class Cut < Input

        attr_reader :from, :to

        def initialize(unfiltered, from:, to:)
          @io = unfiltered
          @from, @to = from, (to.to_f == 0 ? nil : to)

          raise Error.new "cut from: cannot be nil"  if from.nil?
        end

        def filters_for(lbl, ns:)

          # Trimming

          lbl_aux = "tm#{lbl}"
          @io.filters_for(lbl_aux, ns: ns) +
            if from == 0 && !to
              [
                Filter.copy("#{lbl_aux}:v", "#{lbl}:v"),
                Filter.anull("#{lbl_aux}:a", "#{lbl}:a")
              ]
            else
              [
                Filter.trim(from, to, "#{lbl_aux}:v", "#{lbl}:v"),
                Filter.atrim(from, to, "#{lbl_aux}:a", "#{lbl}:a")
              ]
            end
        end

      end

      class Cropped < Input

        attr_reader :crop_ratios

        def initialize(unfiltered, crop:)
          @io = unfiltered
          self.crop_ratios = crop
        end

        def filters_for(lbl, ns:)

          # Cropping

          lbl_aux = "cp#{lbl}"
          @io.filters_for(lbl_aux, ns: ns) +
            [
              Filter.crop(crop_ratios, "#{lbl_aux}:v", "#{lbl}:v"),
              Filter.anull("#{lbl_aux}:a", "#{lbl}:a")
            ]
        end

        private

        CROP_PARAMS = %i[top left bottom right width height]

        def crop_ratios=(ratios)
          @crop_ratios =
            if ratios.is_a?(Numeric)
              {top: ratios, left: ratios, bottom: ratios, right: ratios}
            else
              ratios
            end.tap do |ratios|  # NOTE validation
              next  unless ratios
              raise "Allowed crop params are: #{CROP_PARAMS}"  unless ratios.respond_to?(:keys) && (ratios.keys - CROP_PARAMS).empty?
              ratios.each do |key, value|
                raise Error.new "Crop #{key} must be between 0 and 1 (not '#{value}')"  unless (0...1).include? value
              end
            end
        end

      end

      def initialize(io)
        @io = io
      end

      def options
        " -i #{@io.path}"
      end

      def filters_for(lbl, ns:)
        in_lbl = ns[self]
        raise Error.new "Data corruption"  unless in_lbl

        [
          Filter.copy("#{in_lbl}:v", "#{lbl}:v"),
          Filter.anull("#{in_lbl}:a", "#{lbl}:a")
        ]
      end


      def crop(ratio)  # NOTE ratio is either a CROP_PARAMS symbol-ratio hash or a single (global) ratio
        Cropped.new self, crop: ratio
      end

      def cut(from: 0, to: nil)
        Cut.new self, from: from, to: to
      end

    end

    class Output

      def initialize(io, resolution:, fps: 30, &blk)
        @io = io
        @resolution = resolution
        @fps = 30

        instance_exec &blk
      end

      def options(ns)
        # XXX TODO manage stream labels through ns
        raise Error.new "Nothing to roll..."  if @reels.select(&:reel).empty?
        raise Error.new "Supporting just full_screen for now, sorry."  unless @reels.all?(&:full_screen?)

        filters = []

        # Concatting
        segments = []

        prev_reel = nil
        @reels.each_with_index do |curr_reel, i|

          lbl = nil

          # NOTE mapping input to this lbl
          if curr_reel.reel
            lbl = "rl#{i}"
            lbl_aux = "sp#{i}"

            # NOTE Image-Scaling & Image-Padding to match the target resolution

            # XXX full screen only (see exception above)

            filters +=
              curr_reel.reel.filters_for(lbl_aux, ns: ns)
            filters +=
              Filter.scale_pad_fps(target_width, target_height, target_fps, "#{lbl_aux}:v", "#{lbl}:v")
            filters +=
              Filter.anull("#{lbl_aux}:a", "#{lbl}:a")
          end

          trim_prev_at = curr_reel.after || (curr_reel.transition && 0)

          if trim_prev_at

            # NOTE make sure previous reel rolls _long_ enough AND then _just_ enough

            prev_lbl = segments.pop

            lbl_pad = "bl#{prev_lbl}#{i}"
            # NOTE generously padding the previous segment to support for all the cases
            filters +=
              Filter.black_source(trim_prev_at + curr_reel.transition_length, target_resolution, target_fps, "#{lbl_pad}:v")
            filters +=
              Filter.silent_source(trim_prev_at + curr_reel.transition_length, "#{lbl_pad}:a")

            if prev_lbl
              lbl_aux = lbl_pad
              lbl_pad = "pd#{prev_lbl}#{i}"
              filters +=
                Filter.concat_v(["#{prev_lbl}:v", "#{lbl_aux}:v"], "#{lbl_pad}:v")
              filters +=
                Filter.concat_a(["#{prev_lbl}:a", "#{lbl_aux}:a"], "#{lbl_pad}:a")
            end

            if curr_reel.transition
              if trim_prev_at > 0
                filters +=
                  Filter.split("#{lbl_pad}:v", ["#{lbl_pad}a:v", "#{lbl_pad}b:v"])
                filters +=
                  Filter.asplit("#{lbl_pad}:a", ["#{lbl_pad}a:a", "#{lbl_pad}b:a"])
                lbl_pad, lbl_pad_ = "#{lbl_pad}a", "#{lbl_pad}b"
              else
                lbl_pad, lbl_pad_ = nil, lbl_pad
              end
            end

            if lbl_pad
              new_prev_lbl = "tm#{prev_lbl}#{i}a"
              filters +=
                Filter.trim(0, trim_prev_at, "#{lbl_pad}:v", "#{new_prev_lbl}:v")
              filters +=
                Filter.atrim(0, trim_prev_at, "#{lbl_pad}:a", "#{new_prev_lbl}:a")

              segments << new_prev_lbl
            end

            if curr_reel.transition
              # NOTE snip the end of the previous segment and combine with this reel
              lbl_end1 = "tm#{i}b"
              lbl_reel = "tn#{i}"
              if !lbl  # no reel
                lbl_aux = "bk#{i}"
                filters +=
                  Filter.black_source(curr_reel.transition_length, target_resolution, target_fps, "#{lbl_aux}:v")
                filters +=
                  Filter.silent_source(curr_reel.transition_length, "#{lbl_aux}:a")
              end  # NOTE else hope lbl is long enough for the transition
              filters +=
                Filter.trim(trim_prev_at, trim_prev_at + curr_reel.transition_length, "#{lbl_pad_}:v", "#{lbl_end1}:v")
              filters +=
                Filter.atrim(trim_prev_at, trim_prev_at + curr_reel.transition_length, "#{lbl_pad_}:a", "#{lbl_end1}:a")
              filters +=
                Filter.transition_av(curr_reel.transition, target_resolution, target_fps, [lbl_end1, lbl || lbl_aux], lbl_reel)
              lbl = lbl_reel
            end

          end

          segments << lbl  # NOTE can be nil
          prev_reel = curr_reel
        end

        segments_av = segments.compact.reduce([]) do |segments, segment|
          segments + ["#{segment}:v", "#{segment}:a"]
        end

        filters +=
          Filter.concat_av(segments_av)

        "#{Filter.complex_options filters} -s #{@resolution} #{@io.path}"
      end

      def roll(
        reel,
        onto: :full_screen,
        after: nil,
        transition: nil
      )
        raise Error.new "Nothing to roll..."  unless reel
        raise Error.new "Supporting :transition with :after only at the moment, sorry."  unless
          !transition || after || @reels.to_a.empty?

        add_reel reel, after, transition, (onto == :full_screen)
      end

      def cut(
        after: nil,
        transition: nil
      )
        raise Error.new "Nothing to cut..."  if @reels.empty? || @reels.last.reel.nil?

        add_reel nil, after, transition, @reels.last.full_screen?
      end

      private

      def add_reel(reel, after, transition, full_screen)
        raise Error.new "No time to roll..."  if after && after.to_f <= 0

        # NOTE limited functionality (see exception in Filter.transition_av): transition = {effect => duration}
        transition_length = transition.to_h.max_by{|k,v| v}.to_a.last.to_f
        (@reels ||= []) <<
          OpenStruct.new(reel: reel, after: after, transition: transition, transition_length: transition_length, full_screen?: full_screen)
      end

      def target_width
        @target_width ||= @resolution.to_s.split('x')[0].to_i.tap do |width|
          raise Error.new "Width (#{width}) must be divisible by 2, sorry"  unless width % 2 == 0
        end
      end
      def target_height
        @target_height ||= @resolution.to_s.split('x')[1].to_i.tap do |height|
          raise Error.new "Height (#{height}) must be divisible by 2, sorry"  unless height % 2 == 0
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
