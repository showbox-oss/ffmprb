module Ffmprb

  class Process

    class << self

      attr_accessor :duck_audio_volume_hi, :duck_audio_volume_lo,
        :duck_audio_silent_min
      attr_accessor :duck_audio_transition_length,
        :duck_audio_transition_in_start, :duck_audio_transition_out_start

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

      def duck_audio(av_main_i, a_overlay_i, silence, av_main_o,
        volume_lo: duck_audio_volume_lo, volume_hi: duck_audio_volume_hi,
        silent_min: duck_audio_silent_min,
        video: {resolution: Ffmprb::CGA, fps: 30}  # XXX temporary
        )
        Ffmprb.process(av_main_i, a_overlay_i, silence, av_main_o) do |main_input, overlay_input, duck_data, main_output|

          in_main = input(main_input, **(video ? {} : {only: :audio}))
          in_over = input(overlay_input, only: :audio)
          output(main_output, **(video ? {resolution: video[:resolution], fps: video[:fps]} : {})) do
            roll in_main

            ducked_overlay_volume = {0.0 => volume_lo}
            duck_data.each do |silent|
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

    attr_reader :timeout

    def initialize(*args, **opts, &blk)
      @inputs = []
      @timeout = opts[:timeout] || self.class.timeout
    end

    def input(io, only: nil)
      Input.new(io, only: only).tap do |inp|
        @inputs << inp
      end
    end

    def output(io, only: nil, resolution: Ffmprb::CGA, fps: 30, &blk)
      fail Error, "Just one output for now, sorry."  if @output

      @output = Output.new(io, only: only, resolution: resolution, fps: fps).tap do |out|
        out.instance_exec &blk
      end
    end

    # NOTE the one and the only entry-point processing function which spawns threads etc
    def run(limit: nil)  # (async: false)
      # NOTE this is both for the future async: option and according to
      # the threading policy (a parent death will be noticed and handled by children)
      thr = Util::Thread.new do
        # NOTE yes, an exception can occur anytime, and we'll just die, it's ok, see above
        Util.ffmpeg(*command, limit: limit, timeout: timeout).tap do |res|  # XXX just to return something
          Util::Thread.join_children! limit, timeout: timeout
        end
      end
      thr.value  if thr.join limit  # NOTE should not block for more than limit
    end

    def [](obj)
      case obj
      when Input
        @inputs.find_index(obj)
      end
    end

    private

    def command
      input_options + output_options
    end

    def input_options
      @inputs.map(&:options).flatten(1)
    end

    def output_options
      @output.options_for self
    end

  end

end
