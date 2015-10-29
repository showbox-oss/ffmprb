module Ffmprb

  class Process

    class Input

      class Loud < ChainBase

        def initialize(unfiltered, volume:)
          super unfiltered
          @volume = volume

          fail Error, "volume cannot be nil"  if volume.nil?
        end

        def filters_for(lbl, video:, audio:)

          # Modulating volume

          lbl_aux = "ld#{lbl}"
          unfiltered.filters_for(lbl_aux, video: video, audio: audio) +
            [
              *((video && channel?(:video))? Filter.copy("#{lbl_aux}:v", "#{lbl}:v"): nil),
              *((audio && channel?(:audio))? Filter.volume(@volume, "#{lbl_aux}:a", "#{lbl}:a"): nil)
            ]
        end

      end

    end

  end

end
