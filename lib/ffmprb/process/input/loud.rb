module Ffmprb

  class Process

    class Input

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

    end

  end

end
