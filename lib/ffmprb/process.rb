module Ffmprb

  class Process

    class << self

      attr_accessor :duck_audio_volume_hi, :duck_audio_volume_lo,
        :duck_audio_silent_min
      attr_accessor :duck_audio_transition_length,
        :duck_audio_transition_in_start, :duck_audio_transition_out_start

      attr_accessor :output_video_resolution
      attr_accessor :output_video_fps
      attr_accessor :output_audio_encoder

      attr_accessor :timeout

      def intermediate_channel_extname(*media)
        if media == [:video]
          '.y4m'
        elsif media == [:audio]
          '.wav'
        elsif media.sort == [:audio, :video]
          '.flv'
        else
          fail Error, "I don't know how to channel [#{media.join ', '}]"
        end
      end

      def output_video_options
        {
          resolution: output_video_resolution,
          fps: output_video_fps
        }
      end
      def output_audio_options
        {
          encoder: output_audio_encoder
        }
      end

      # NOTE Temporarily, av_main_i/o and not a_main_i/o
      def duck_audio(av_main_i, a_overlay_i, silence, av_main_o,
        volume_lo: duck_audio_volume_lo,
        volume_hi: duck_audio_volume_hi,
        silent_min: duck_audio_silent_min,
        process_options: {},
        video:,  # NOTE Temporarily, video should not be here
        audio:
        )
        Ffmprb.process **process_options do

          in_main = input(av_main_i)
          in_over = input(a_overlay_i)
          output(av_main_o, video: video, audio: audio) do
            roll in_main

            ducked_overlay_volume = {0.0 => volume_lo}
            silence.each do |silent|
              next  if silent.end_at && silent.start_at && (silent.end_at - silent.start_at) < silent_min

              transition_in_start = silent.start_at + Process.duck_audio_transition_in_start
              ducked_overlay_volume.merge!(
                [transition_in_start, 0.0].max => volume_lo,
                (transition_in_start + Process.duck_audio_transition_length) => volume_hi
              )  if silent.start_at

              transition_out_start = silent.end_at + Process.duck_audio_transition_out_start
              ducked_overlay_volume.merge!(
                [transition_out_start, 0.0].max => volume_hi,
                (transition_out_start + Process.duck_audio_transition_length) => volume_lo
              )  if silent.end_at
            end
            overlay in_over.volume ducked_overlay_volume

            Ffmprb.logger.debug "Ducking audio with volumes: {#{ducked_overlay_volume.map{|t,v| "#{t}: #{v}"}.join ', '}}"
          end

        end
      end

    end

    attr_accessor :timeout
    attr_accessor :ignore_broken_pipe

    def initialize(*args, **opts)
      @inputs, @outputs = [], []
      self.timeout = opts.delete(:timeout) || self.class.timeout

      self.ignore_broken_pipe = opts.delete(:ignore_broken_pipe)
      fail Error, "Unknown options: #{opts}"  unless opts.empty?
    end

    def input(io)
      Input.new(io, self).tap do |inp|
        @inputs << inp
      end
    end

    def temp_input(extname)  # XXX SPEC ME
      input(nil).tap do |inp|
        inp.temporise! extname
      end
    end

    def input_label(input)
      @inputs.index input
    end

    def output(io, video: true, audio: true, &blk)
      Output.new(io, self,
        video: channel_params(video, self.class.output_video_options),
        audio: channel_params(audio, self.class.output_audio_options)
      ).tap do |out|
        @outputs << out
        out.instance_exec &blk  if blk
      end
    end

    def output_index(output)
      @outputs.index output
    end

    # NOTE the one and the only entry-point processing function which spawns threads etc
    def run(limit: nil)  # TODO (async: false)
      # NOTE this is both for the future async: option and according to
      # the threading policy (a parent death will be noticed and handled by children)
      thr = Util::Thread.new do
        # NOTE yes, an exception can occur anytime, and we'll just die, it's ok, see above
        # XXX just to return something -- no apparent practical use
        cmd = command
        Util.ffmpeg(*cmd, limit: limit, timeout: timeout, ignore_broken_pipe: @ignore_broken_pipe).tap do |res|
          Util::Thread.join_children! limit, timeout: timeout
        end
      end
      thr.value  if thr.join limit  # NOTE should not block for more than limit
    end

    private

    def command
      input_options + filter_options + output_options
    end

    def input_options
      @inputs.map(&:options).flatten(1)
    end

    def filter_options
      Filter.complex_options @outputs.map(&:filters).reduce(:+)
    end

    def output_options
      @outputs.map(&:options).flatten(1)
    end

    def channel_params(value, default)
      if value
        default.merge(value == true ? {} : value.to_h)
      elsif value != false
        {}
      end
    end

  end

end

require_relative 'process/input'
require_relative 'process/output'
