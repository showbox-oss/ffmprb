module Ffmprb

  class Process

    class Input

      class ChainBase < Input

        def initialize(unfiltered)
          @io = unfiltered
        end

        def channel(medium)
          @io.channel medium
        end
        
      end

    end

  end

end
