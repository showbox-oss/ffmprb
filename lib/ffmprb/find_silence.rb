module Ffmprb

  def self.find_silence(input_file, output_file)
    logger.debug "Finding silence (#{input_file.path}->#{output_file.path})"
    filters = Filter.silencedetect
    options = ['-i', input_file.path, *Filter.complex_options(filters), output_file.path]
    silence = []
    Util.ffmpeg(*options).split("\n").each do |line|
      next  unless line =~ /^\[silencedetect\s.*\]\s*silence_(\w+):\s*(\d+\.?d*)/
      case $1
      when 'start'
        silence << OpenStruct.new(start_at: $2.to_f)
      when 'end'
        if silence.empty?
          silence << OpenStruct.new(start_at: 0.0, end_at: $2.to_f)
        else
          raise Error, "ffmpeg is being stupid: silence_end with no silence_start"  if silence.last.end_at
          silence.last.end_at = $2.to_f
        end
      else
        Ffmprb.warn "Unknown silence mark: #{$1}"
      end
    end

    logger.debug "Found silence (#{input_file.path}->#{output_file.path}): [#{silence.map{|t,v| "#{t}: #{v}"}}]"
    silence
  end

end
