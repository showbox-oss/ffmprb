module Ffmprb

  class Process

    class Input

      class Cropped < ChainBase

        attr_reader :crop_ratios

        def initialize(unfiltered, crop:)
          super unfiltered
          self.crop_ratios = crop
        end

        def filters_for(lbl, process:, video:, audio:)

          # Cropping

          lbl_aux = "cp#{lbl}"
          lbl_tmp = "tmp#{lbl}"
          @io.filters_for(lbl_aux, process: process, video: video, audio: audio) +
            [
              *((video && channel?(:video))? [
                Filter.crop(crop_ratios, "#{lbl_aux}:v", "#{lbl_tmp}:v"),
                # XXX this fixup is temporary, leads to resolution loss on crop etc...
                Filter.scale_pad_fps(video.resolution, video.fps, "#{lbl_tmp}:v", "#{lbl}:v")
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

    end

  end

end
