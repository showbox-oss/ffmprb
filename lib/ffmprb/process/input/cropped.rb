module Ffmprb

  class Process

    class Input

      class Cropped < ChainBase

        attr_reader :ratios

        def initialize(unfiltered, crop:)
          super unfiltered
          self.ratios = crop
        end

        def filters_for(lbl, video:, audio:)

          # Cropping

          lbl_aux = "cp#{lbl}"
          lbl_tmp = "tmp#{lbl}"
          unfiltered.filters_for(lbl_aux, video: unsize(video), audio: audio) +
            [
              *((video && channel?(:video))? [
                Filter.crop_prop(ratios, "#{lbl_aux}:v", "#{lbl_tmp}:v"),
                Filter.scale_pad(video.resolution, "#{lbl_tmp}:v", "#{lbl}:v")
              ]: nil),
              *((audio && channel?(:audio))? Filter.anull("#{lbl_aux}:a", "#{lbl}:a"): nil)
            ]
        end

        private

        CROP_PARAMS = %i[top left bottom right width height]

        def unsize(video)
          fail Error, "requires resolution"  unless video.resolution
          OpenStruct.new(video).tap do |video|
            video.resolution = nil
          end
        end

        def ratios=(ratios)
          @ratios =
            if ratios.is_a?(Numeric)
              {top: ratios, left: ratios, bottom: ratios, right: ratios}
            else
              ratios
            end.tap do |ratios|  # NOTE validation
              fail "Allowed crop params are: #{CROP_PARAMS}"  unless
                ratios && ratios.respond_to?(:keys) && (ratios.keys - CROP_PARAMS).empty?

              ratios.each do |key, value|
                fail Error, "Crop #{key} must be between 0 and 1 (not '#{value}')"  unless
                  (0...1).include? value
              end
            end
        end

      end

    end

  end

end
