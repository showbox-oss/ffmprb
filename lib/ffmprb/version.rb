module Ffmprb
  VERSION = '0.10.0'


  FIREBASE_AVAILABLE =
    begin
      require 'firebase'
      true
    rescue Exception
    end
end
