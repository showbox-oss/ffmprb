module Ffmprb

  class Process

    class Input

      class Cropped < Input

        attr_reader :crop_ratios

        def initialize(unfiltered, crop:)
          @io = unfiltered
          self.crop_ratios = crop
        end

        def filters_for(lbl, process:, output:, video: true, audio: true)

          # Cropping

          lbl_aux = "cp#{lbl}"
          lbl_tmp = "tmp#{lbl}"
          @io.filters_for(lbl_aux, process: process, output: output, video: video, audio: audio) +
            [
              *((video && channel?(:video))? [
                Filter.crop(crop_ratios, "#{lbl_aux}:v", "#{lbl_tmp}:v"),
                # XXX this fixup is temporary, leads to resolution loss on crop etc...
                Filter.scale_pad_fps(output.target_width, output.target_height, output.target_fps, "#{lbl_tmp}:v", "#{lbl}:v")
              ]: nil),
              *((audio && channel?(:audio))? Filter.anull("#{lbl_aux}:a", "#{lbl}:a"): nil)
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
              fail "Allowed crop params are: #{CROP_PARAMS}"  unless ratios.respond_to?(:keys) && (ratios.keys - CROP_PARAMS).empty?
              ratios.each do |key, value|
                fail Error, "Crop #{key} must be between 0 and 1 (not '#{value}')"  unless (0...1).include? value
              end
            end
        end

      end

      class Cut < Input

        attr_reader :from, :to

        def initialize(unfiltered, from:, to:)
          @io = unfiltered
          @from, @to = from, (to.to_f == 0 ? nil : to)

          fail Error, "cut from: must be"  unless from
          fail Error, "cut from: must be less than to:"  unless !to || from < to
        end

        def filters_for(lbl, process:, output:, video: true, audio: true)

          # Trimming

          lbl_aux = "tm#{lbl}"
          @io.filters_for(lbl_aux, process: process, output: output, video: video, audio: audio) +
            if to
              lbl_blk = "bl#{lbl}"
              lbl_pad = "pd#{lbl}"
              [
                *((video && channel?(:video))?
                  Filter.blank_source(to - from, output.target_resolution, output.target_fps, "#{lbl_blk}:v") +
                  Filter.concat_v(["#{lbl_aux}:v", "#{lbl_blk}:v"], "#{lbl_pad}:v") +
                  Filter.trim(from, to, "#{lbl_pad}:v", "#{lbl}:v")
                  : nil),
                *((audio && channel?(:audio))?
                  Filter.silent_source(to - from, "#{lbl_blk}:a") +
                  Filter.concat_a(["#{lbl_aux}:a", "#{lbl_blk}:a"], "#{lbl_pad}:a") +
                  Filter.atrim(from, to, "#{lbl_pad}:a", "#{lbl}:a")
                  : nil)
              ]
            elsif from == 0
              [
                *((video && channel?(:video))? Filter.copy("#{lbl_aux}:v", "#{lbl}:v"): nil),
                *((audio && channel?(:audio))? Filter.anull("#{lbl_aux}:a", "#{lbl}:a"): nil)
              ]
            else  # !to
              [
                *((video && channel?(:video))? Filter.trim(from, nil, "#{lbl_aux}:v", "#{lbl}:v"): nil),
                *((audio && channel?(:audio))? Filter.atrim(from, nil, "#{lbl_aux}:a", "#{lbl}:a"): nil)
              ]
            end
        end

      end

      class Loud < Input

        attr_reader :from, :to

        def initialize(unfiltered, volume:)
          @io = unfiltered
          @volume = volume

          fail Error, "volume cannot be nil"  if volume.nil?
        end

        def filters_for(lbl, process:, output:, video: true, audio: true)

          # Modulating volume

          lbl_aux = "ld#{lbl}"
          @io.filters_for(lbl_aux, process: process, output: output, video: video, audio: audio) +
            [
              *((video && channel?(:video))? Filter.copy("#{lbl_aux}:v", "#{lbl}:v"): nil),
              *((audio && channel?(:audio))? Filter.volume(@volume, "#{lbl_aux}:a", "#{lbl}:a"): nil)
            ]
        end

      end


      def initialize(io, only: nil)
        @io = resolve(io)
        @channels = [*only]
        @channels = nil  if @channels.empty?
        raise Error, "Inadequate A/V channels"  if
          [:video, :audio].any?{|medium| !@io.channel?(medium) && channel?(medium, true)}
      end

      def options
        ['-i', @io.path]
      end

      def filters_for(lbl, process:, output:, video: true, audio: true)

        # Channelling

        if @io.respond_to?(:filters_for)
          lbl_aux = "au#{lbl}"
          @io.filters_for(lbl_aux, process: process, output: output, video: video, audio: audio) +
            [
              *((video && @io.channel?(:video))?
                (channel?(:video)? Filter.copy("#{lbl_aux}:v", "#{lbl}:v"): Filter.nullsink("#{lbl_aux}:v")):
                nil),
              *((audio && @io.channel?(:audio))?
                (channel?(:audio)? Filter.anull("#{lbl_aux}:a", "#{lbl}:a"): Filter.anullsink("#{lbl_aux}:a")):
                nil)
            ]
        else
          in_lbl = process[self]
          raise Error, "Data corruption"  unless in_lbl
          [
            # XXX this fixup is temporary, leads to resolution loss on crop etc... *(video && @io.channel?(:video) && channel?(:video)? Filter.copy("#{in_lbl}:v", "#{lbl}:v"): nil),
            *(video && @io.channel?(:video) && channel?(:video)? Filter.scale_pad_fps(output.target_width, output.target_height, output.target_fps, "#{in_lbl}:v", "#{lbl}:v"): nil),
            *(audio && @io.channel?(:audio) && channel?(:audio)? Filter.anull("#{in_lbl}:a", "#{lbl}:a"): nil)
          ]
        end
      end

      def video
        Input.new self, only: :video
      end

      def audio
        Input.new self, only: :audio
      end

      def crop(ratio)  # NOTE ratio is either a CROP_PARAMS symbol-ratio hash or a single (global) ratio
        Cropped.new self, crop: ratio
      end

      def cut(from: 0, to: nil)
        Cut.new self, from: from, to: to
      end

      def mute
        Loud.new self, volume: 0
      end

      def volume(vol)
        Loud.new self, volume: vol
      end

      def channel?(medium, force=false)
        return !!@channels && @channels.include?(medium) && @io.channel?(medium)  if force

        (!@channels || @channels.include?(medium)) && @io.channel?(medium)
      end

      protected

      def resolve(io)
        return io  unless io.is_a? String

        case io
        when /^\/\w/
          File.open(io).tap do |file|
            Ffmprb.logger.warn "Input file does no exist (#{file.path}), will probably fail"  unless file.exist?
          end
        else
          fail Error, "Cannot resolve input: #{io}"
        end
      end

    end

  end

end
