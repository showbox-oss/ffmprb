module Ffmprb

  class Process

    class Input

      def video
        Channeled.new self, audio: false
      end

      def audio
        Channeled.new self, video: false
      end

      class Channeled < ChainBase

        def initialize(unfiltered, video: true, audio: true)
          super unfiltered
          @limited_channels = {video: video, audio: audio}
        end

        def channel(medium)
          super(medium)  if @limited_channels[medium]
        end

        def filters_for(lbl, video:, audio:)

          # Doing nothing

          unfiltered.filters_for lbl,
            video: channel?(:video) && video, audio: channel?(:audio) && audio
        end

      end

    end

  end

end
