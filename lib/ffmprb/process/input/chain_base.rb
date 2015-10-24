module Ffmprb

  class Process

    class Input

      class ChainBase < Input

        def initialize(unfiltered)
          @io = unfiltered
        end

        protected

        def unfiltered
          @io
        end

      end

    end

  end

end
