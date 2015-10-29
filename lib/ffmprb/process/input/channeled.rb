module Ffmprb

  class Process

    class Input

      class Channeled < ChainBase

        def initialize(unfiltered, video: true, audio: true)
          super unfiltered
          @limited_channels = {video: video, audio: audio}
        end

        def channel(medium)
          super(medium)  if @limited_channels[medium]
        end

      end

    end

  end

end
