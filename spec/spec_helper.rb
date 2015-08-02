require 'byebug'
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'ffmprb'

RSpec.configure do |config|

  # NOTE generated media files

  # XXX https://github.com/rspec/rspec-core/issues/1031#issuecomment-120706058
  # config.around :all do |group|
  #   Ffmprb::File.temp('.mp4') do |av_file_gor|
  #     system("ffmpeg -y -filter_complex 'color=red:r=60:d=6:s=320x240 [red]; color=green:r=60:d=6:s=280x200 [green]; [red] [green] overlay=20:20; sine=1000:d=6' -s 320x240 #{av_file_gor.path}")
  #     @av_file_gor = av_file_gor
  #     Ffmprb::File.temp('.y4m') do |v_file|
  #       system("ffmpeg -y -filter_complex 'color=red:r=30:d=6:s=320x240 [red]; color=green:r=30:d=6:s=280x200 [green]; [red] [green] overlay=20:20' -pix_fmt yuv420p #{v_file.path}")
  #       @v_file = v_file
  #       Ffmprb::File.temp('.y4m') do |v_file|
  #         system("ffmpeg -y -filter_complex 'color=red:r=30:d=6:s=320x240 [red]; color=green:r=30:d=6:s=280x200 [green]; [red] [green] overlay=20:20' -pix_fmt yuv420p #{v_file.path}")
  #         @v_file = v_file
  #
  #         group.run_examples
  #       end
  #     end
  #   end
  # end

  config.before :all do
    @av_file_gor = Ffmprb::File.temp('.mp4')
    Ffmprb::Util.ffmpeg *Ffmprb::Filter.complex_options('color=red:r=60:d=6:s=320x240 [red]', 'color=green:r=60:d=6:s=280x200 [green]', '[red] [green] overlay=20:20', 'sine=1000:d=6'), @av_file_gor.path
    @av_file_wtb = Ffmprb::File.temp('.mp4')
    Ffmprb::Util.ffmpeg *Ffmprb::Filter.complex_options('color=white:s=320x240:r=60:d=4, split [wh1a] [wh1b]', 'color=black:s=320x240:r=60:d=4, split [bl1a] [bl1b]', 'sine=880:d=4, asplit [na5a] [na5b]', 'aevalsrc=0:d=4, asplit [si1a] [si1b]', '[wh1a] [na5a] [bl1a] [si1a] [wh1b] [na5b] [bl1b] [si1b] concat=4:v=1:a=1'), @av_file_wtb.path
    @av_file_ro7 = Ffmprb::File.temp('.flv')
    Ffmprb::Util.ffmpeg *Ffmprb::Filter.complex_options('color=red:r=60:d=2:s=320x240 [red]', 'color=orange:r=60:d=2:s=320x240 [orange]', 'color=yellow:r=60:d=2:s=320x240 [yellow]', 'color=green:r=60:d=2:s=320x240 [green]', 'color=blue:r=60:d=2:s=320x240 [blue]', 'color=indigo:r=60:d=2:s=320x240 [indigo]', 'color=violet:r=60:d=2:s=320x240 [violet]', 'sine=1046.50:d=2 [c6]', 'sine=1174.66:d=2 [d6]', 'sine=1318.51:d=2 [e6]', 'sine=1396.91:d=2 [f6]', 'sine=1567.98:d=2 [g6]', 'sine=1760.00:d=2 [a6]', 'sine=1975.53:d=2 [b6]', '[red] [c6] [orange] [d6] [yellow] [e6] [green] [f6] [blue] [g6] [indigo] [a6] [violet] [b6] concat=7:v=1:a=1'), @av_file_ro7.path
    @v_file = Ffmprb::File.temp('.y4m')
    # XXX produces warning: [yuv4mpegpipe @ 0xXXXX] Encoder did not produce proper pts, making some up.
    Ffmprb::Util.ffmpeg *Ffmprb::Filter.complex_options('color=red:r=30:d=6:s=320x240, setpts=PTS-STARTPTS [red]', 'color=green:r=30:d=6:s=280x200 [green]', '[red] [green] overlay=20:20'), '-pix_fmt', 'yuv420p', @v_file.path
    @a_file = Ffmprb::File.temp('.mp3')
    Ffmprb::Util.ffmpeg *Ffmprb::Filter.complex_options('sine=666:d=4, asplit [aa5a] [aa5b]', 'aevalsrc=0:d=4, asplit [si1a] [si1b]', '[aa5a] [si1a] [aa5b] [si1b] concat=4:v=0:a=1'), @a_file.path
  end

  config.after :all do
    @av_file_gor.remove
    @av_file_wtb.remove
    @v_file.remove
    @a_file.remove
  end

end

RSpec::Matchers.define :be_approximately do |expected|
  define_method :is_approximately? do |actual|
    ((actual - expected)/(expected || 1)).abs < 0.06
  end
  match {|actual| is_approximately? actual}

  failure_message_for_should do |actual|
    "expected that #{actual} would be within 0.06 of #{expected}"
  end
end

RSpec::Matchers.define :be_ascending do
  define_method :is_ascending? do |actual|
    actual.reduce do |prev_vol, vol|
      return false  unless !prev_vol || vol > prev_vol
      vol
    end
    true
  end
  match {|actual| is_ascending? actual}

  failure_message_for_should do |actual|
    "expected that #{actual} would be in ascending order"
  end
end
