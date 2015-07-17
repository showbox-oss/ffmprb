module Ffmprb

  module Util

    # NOTE doesn't have specs (and not too proud about it)
    module Synchro

      module ClassMethods

        def handle_synchronously(*methods)
          prepend Module.new do

            methods.each do |method|

              define_method method do
                @_synchro.synchronize do
                  super
                end
              end

            end

          end
        end

      end

      module InstanceMethods

        def initialize(*args)
          @_synchro = Monitor.new
          super
        end

      end

      def self.included(mod)
        mod.prepend InstanceMethods
        mod.extend ClassMethods
      end

    end

  end

end
