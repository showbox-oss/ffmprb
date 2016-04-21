module Ffmprb

  class Execution

    def initialize(*params, script:)
      @params = params
      @script = eval("lambda{#{script}}")
    end

    def run
      Ffmprb.process *@params, ignore_broken_pipes: false, &@script
    end

  end

  def self.execute
    return STDERR.puts "Usage: (not quite usual) $ ffmprb streams... < script.ffmprb"  unless
      ARGV.length > 1 && ARGV.grep(/^-/).empty?

    Execution.new(*ARGV, script: STDIN.read).run
  end

end
