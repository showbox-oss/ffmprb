module Ffmprb

  class Process

    class Input

      class ChainBase < Input

        def initialize(unfiltered)
          @io = unfiltered
        end

        def unfiltered; @io; end
        def unfiltered=(input); @io = input; end


        def chain_copy(src_input)  # XXX SPEC ME
          dup.tap do |top|
            top.unfiltered = unfiltered.chain_copy(src_input)
          end
        end

      end

    end

  end

end
