module Ffmprb

  class << self

    def find_silence(input_file, output_file)
      logger.debug "Finding silence (#{input_file.path}->#{output_file.path})"
      silence = []
      Util.ffmpeg('-i', input_file.path, *find_silence_detect_options, output_file.path).
        scan(SILENCE_DETECT_REGEX).each do |mark, time|
        time = time.to_f

        case mark
        when 'start'
          silence << OpenStruct.new(start_at: time)
        when 'end'
          if silence.empty?
            silence << OpenStruct.new(start_at: 0.0, end_at: time)
          else
            fail Error, "ffmpeg is being stupid: silence_end with no silence_start"  if silence.last.end_at
            silence.last.end_at = time
          end
        else
          Ffmprb.warn "Unknown silence mark: #{mark}"
        end
      end
      logger.debug "Found silence (#{input_file.path}->#{output_file.path}): [#{silence.map{|t,v| "#{t}: #{v}"}}]"
      silence
    end

    private

    SILENCE_DETECT_REGEX = /\[silencedetect\s.*\]\s*silence_(\w+):\s*(\d+\.?\d*)/

    def find_silence_detect_options
      Filter.complex_options Filter.silencedetect
    end

  end

end
