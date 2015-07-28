require 'byebug'
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'ffmprb'

RSpec.configure do |config|

  # NOTE generated media files

  # XXX https://github.com/rspec/rspec-core/issues/1031#issuecomment-120706058
  # config.around :all do |group|
  #   Ffmprb::File.temp('.mp4') do |av_file_gor|
  #     system("ffmpeg -y -filter_complex 'color=c=red:r=60:d=6:s=320x240 [red]; color=c=green:r=60:d=6:s=280x200 [green]; [red] [green] overlay=20:20; sine=1000:d=6' -s 320x240 #{av_file_gor.path}")
  #     @av_file_gor = av_file_gor
  #     Ffmprb::File.temp('.y4m') do |v_file|
  #       system("ffmpeg -y -filter_complex 'color=c=red:r=30:d=6:s=320x240 [red]; color=c=green:r=30:d=6:s=280x200 [green]; [red] [green] overlay=20:20' -pix_fmt yuv420p #{v_file.path}")
  #       @v_file = v_file
  #       Ffmprb::File.temp('.y4m') do |v_file|
  #         system("ffmpeg -y -filter_complex 'color=c=red:r=30:d=6:s=320x240 [red]; color=c=green:r=30:d=6:s=280x200 [green]; [red] [green] overlay=20:20' -pix_fmt yuv420p #{v_file.path}")
  #         @v_file = v_file
  #
  #         group.run_examples
  #       end
  #     end
  #   end
  # end

  config.before :all do
    @av_file_gor = Ffmprb::File.temp('.mp4')
    Ffmprb::Util.ffmpeg *Ffmprb::Filter.complex_options('color=c=red:r=60:d=6:s=320x240 [red]', 'color=c=green:r=60:d=6:s=280x200 [green]', '[red] [green] overlay=20:20', 'sine=1000:d=6'), @av_file_gor.path
    @av_file_wtb = Ffmprb::File.temp('.mp4')
    Ffmprb::Util.ffmpeg *Ffmprb::Filter.complex_options('color=white:s=320x240:r=60:d=4, split [wh1a] [wh1b]', 'color=black:s=320x240:r=60:d=4, split [bl1a] [bl1b]', 'sine=880:d=4, asplit [na5a] [na5b]', 'aevalsrc=0:d=4, asplit [si1a] [si1b]', '[wh1a] [na5a] [bl1a] [si1a] [wh1b] [na5b] [bl1b] [si1b] concat=4:v=1:a=1'), @av_file_wtb.path
    @v_file = Ffmprb::File.temp('.y4m')
    # XXX produces warning: [yuv4mpegpipe @ 0xXXXX] Encoder did not produce proper pts, making some up.
    Ffmprb::Util.ffmpeg *Ffmprb::Filter.complex_options('color=c=red:r=30:d=6:s=320x240, setpts=PTS-STARTPTS [red]', 'color=c=green:r=30:d=6:s=280x200 [green]', '[red] [green] overlay=20:20'), '-pix_fmt', 'yuv420p', @v_file.path
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


def be_approximately(sec)
  be_within(0.06 * sec).of sec
end
