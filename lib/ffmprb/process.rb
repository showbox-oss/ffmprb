require 'ostruct'

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
      raise Error.new("Just one output for now, sorry.")  if @output
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
          @from, @to = from, to
        end

        def filters_for(lbl, ns:)

          # Trimming

          lbl_aux = "tm#{lbl}"
          @io.filters_for(lbl_aux, ns: ns) <<
            "[#{lbl_aux}] trim=#{from}:#{to} [#{lbl}]"
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
          @io.filters_for(lbl_aux, ns: ns) <<
            "[#{lbl_aux}] crop=#{crop_exps(crop_ratios).join ':'} [#{lbl}]"
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
                raise Error.new("Crop #{key} must be between 0 and 1 (not '#{value}')")  unless (0...1).include? value
              end
            end
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

        ["[#{in_lbl}] copy [#{lbl}]"]
      end


      def crop(ratio)  # NOTE ratio is either a CROP_PARAMS symbol-ratio hash or a single (global) ratio
        Cropped.new self, crop: ratio
      end

      def cut(from:, to:)
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
        raise Error.new "supporting just full_screen for now"  unless @reels.all?(&:full_screen)

        filters = []

        # Concatting
        segments = []

        # NOTE if the first reel is delayed, add some black frames
        if @reels[0].after.to_f != 0
          lbl = 'bl0'
          filters <<
            black_source(@reels[0].after, lbl)
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
              black_source(@reels[i+1].after, lbl_aux) <<
              "[#{lbl}] [#{lbl_aux}] concat [#{lbl_pad}]"

            lbl = "tm#{i}"
            filters <<
              "[#{lbl_pad}] trim=0:#{@reels[i+1].after} [#{lbl}]"
          end

          segments << lbl
        end

        if segments.size > 1

          # Image-Scaling & Image-Padding to match the target resolution

          # XXX full screen only
          w, h, i = target_width, target_height, 0
          segments = segments.map do |segment|
            "sp#{i}".tap do |lbl_aux|
              filters <<
                "[#{segment}] scale=iw*min(#{w}/iw\\,#{h}/ih):ih*min(#{w}/iw\\,#{h}/ih), pad=#{w}:#{h}:(#{w}-iw*min(#{w}/iw\\,#{h}/ih))/2:(#{h}-ih*min(#{w}/iw\\,#{h}/ih))/2 [#{lbl_aux}]"
              i += 1
            end
          end

          filters <<
            "#{segments.map{|s| "[#{s}]"}.join ' '} concat=n=#{segments.size}"
        else  # segments.size == 1
          filters << "[#{segments.first}] copy"
        end


        filter_complex = " -filter_complex '#{filters.join '; '}'"  unless filters.empty?
        "#{filter_complex} -s #{@resolution} #{@io.path}"
      end

      def roll(reel, full_screen: false, after: nil)
        @reels ||= []
        @reels << OpenStruct.new.tap do |r|
          r.reel = reel
          r.full_screen = full_screen
          r.after = after
        end
      end

      def cut(after:)
        raise Error.new "Nothing to cut..."  if @reels.empty? || @reels.last.reel.nil?

        @reels << OpenStruct.new.tap do |r|
          r.reel = nil
          r.full_screen = @reels.last.full_screen
          r.after = after
        end
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

      def black_source(duration, label)
        "color=black:duration=#{duration} [#{label}]"
      end

    end

  end

  def self.process(*args, &blk)
    Process.new *args, &blk
  end

end
