require 'thor'

module Ffmprb

  class Execution < Thor

    def self.exit_on_failure?; true; end

    class_option :debug, :type => :boolean, :default => false
    class_option :verbose, :aliases => '-v', :type => :boolean, :default => false
    class_option :quiet, :aliases => '-q', :type => :boolean, :default => false

    default_task :process

    desc :process, "Reads an ffmprb script from STDIN and carries it out. See #{GEM_GITHUB_URL}"
    def process(*ios)
      script = eval("lambda{#{STDIN.read}}")
      Ffmprb.log_level =
        if options[:debug]
          Logger::DEBUG
        elsif options[:verbose]
          Logger::INFO
        elsif options[:quiet]
          Logger::ERROR
        else
          Logger::WARN
        end
      Ffmprb.process *ios, ignore_broken_pipes: false, &script
    end

    # NOTE a hack from http://stackoverflow.com/a/23955971/714287
    def method_missing(method, *args)
      args = [:process, method.to_s] + args
      self.class.start(args)
    end

  end

end
