module Ffmprb
  VERSION = '0.9.6'


  FIREBASE_AVAILABLE =
    begin
      require 'firebase'
      true
    rescue Exception
    end
end
