module Ffmprb

  class Process

    class Input

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
