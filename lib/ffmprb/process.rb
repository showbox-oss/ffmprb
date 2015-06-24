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
                Filter.amix("#{lbl_aux}:a", "#{lbl}:a")
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
              Filter.amix("#{lbl_aux}:a", "#{lbl}:a")
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
          Filter.amix("#{in_lbl}:a", "#{lbl}:a")
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

      def initialize(io, resolution:, &blk)
        @io = io
        @resolution = resolution

        instance_exec &blk
      end

      def options(ns)
        raise Error.new "Nothing to roll..."  if @reels.select(&:reel).empty?
        raise Error.new "supporting just full_screen for now"  unless @reels.all?(&:full_screen?)

        filters = []

        # Concatting
        segments = []

        # NOTE if the first reel is delayed, add some black frames
        if @reels[0].after.to_f != 0
          lbl = 'bl0'
          filters <<
            Filter.black_source(@reels[0].after, "#{lbl}:v") <<
            Filter.silent_source(@reels[0].after, "#{lbl}:a")
          segments << lbl
        end

        @reels.each_with_index do |r, i|
          next  unless r.reel  # NOTE cuts are reels without reels, useful for their :after's below

          lbl = "rl#{i}"
          filters += r.reel.filters_for(lbl, ns: ns)

          # Time-Padding & Time-Trimming wrt :after's

          if @reels[i+1] && @reels[i+1].after.to_f != 0
            lbl_aux = "bl#{i+1}"
            lbl_pad = "pd#{i}"
            filters <<
              Filter.black_source(@reels[i+1].after, "#{lbl_aux}:v") <<
              Filter.silent_source(@reels[i+1].after, "#{lbl_aux}:a") <<
              Filter.concat_v(["#{lbl}:v", "#{lbl_aux}:v"], "#{lbl_pad}:v") <<
              Filter.concat_a(["#{lbl}:a", "#{lbl_aux}:a"], "#{lbl_pad}:a")

            lbl = "tm#{i}"
            filters <<
              Filter.trim(0, @reels[i+1].after, "#{lbl_pad}:v", "#{lbl}:v") <<
              Filter.atrim(0, @reels[i+1].after, "#{lbl_pad}:a", "#{lbl}:a")
          end

          segments << lbl
        end

        # Image-Scaling & Image-Padding to match the target resolution

        # XXX full screen only
        i = 0
        segments_av = segments.reduce([]) do |segments, segment|
          lbl_aux = "sp#{i}"

          filters <<
            Filter.scale_pad(target_width, target_height, "#{segment}:v", "#{lbl_aux}:v") <<
            Filter.amix("#{segment}:a", "#{lbl_aux}:a")
          i += 1
          segments += ["#{lbl_aux}:v", "#{lbl_aux}:a"]
        end

        filters <<
          Filter.concat_av(segments_av)

        "#{Filter.complex_options filters} -s #{@resolution} #{@io.path}"
      end

      def roll(
        reel,
        onto: :full_screen,
        after: nil
      )
        (@reels ||= []) <<
          OpenStruct.new(reel: reel, after: after, full_screen?: (onto == :full_screen))
      end

      def cut(
        after: nil
      )
        raise Error.new "Nothing to cut..."  if @reels.empty? || @reels.last.reel.nil?

        (@reels ||= []) <<
          OpenStruct.new(reel: nil, after: after, full_screen?: @reels.last.full_screen?)
      end

      private

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

    end

  end

  def self.process(*args, &blk)
    Process.new *args, &blk
  end

end
