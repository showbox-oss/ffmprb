# ffmprb

A DSL (Damn-Simple Language) for FFmpeg and ffriends.

Allows for code like
```ruby
Ffmprb.process(Ffmprb::File.open('flick.avi'), Ffmprb::File.create('cine.mp4')) do |file_input, file_output|

  in1 = input(file_input)
  output(file_output, resolution: Ffmprb::QVGA) do
    roll in1.cut(from: 2, to: 4).crop(0.25), :onto => :full_screen
    roll in1, :onto => :full_screen
  end

end
```
and saves you from the horrors of (the native ffmpeg equivalent)
```
ffmpeg -y -i flick.avi -filter_complex '[0:v] copy [tmcprl0:v]; [0:a] amix=1 [tmcprl0:a]; [tmcprl0:v] trim=2:4, setpts=PTS-STARTPTS [cprl0:v]; [tmcprl0:a] atrim=2:4, asetpts=PTS-STARTPTS [cprl0:a]; [cprl0:v] crop=x=in_w*0.25:y=in_h*0.25:w=in_w*0.5:h=in_h*0.5 [rl0:v]; [cprl0:a] amix=1 [rl0:a]; [0:v] copy [rl1:v]; [0:a] amix=1 [rl1:a]; [rl0:v] scale=iw*min(320/iw\,240/ih):ih*min(320/iw\,240/ih), pad=320:240:(320-iw*min(320/iw\,240/ih))/2:(240-ih*min(320/iw\,240/ih))/2 [sp0:v]; [rl0:a] amix=1 [sp0:a]; [rl1:v] scale=iw*min(320/iw\,240/ih):ih*min(320/iw\,240/ih), pad=320:240:(320-iw*min(320/iw\,240/ih))/2:(240-ih*min(320/iw\,240/ih))/2 [sp1:v]; [rl1:a] amix=1 [sp1:a]; [sp0:v] [sp0:a] [sp1:v] [sp1:a] concat=2:v=1:a=1' -s 320x240 cine.mp4
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ffmprb'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ffmprb

## Usage

TODO: Write usage instructions here

Ffmprb::File.info('spec/support/assets/green-red_frame-20-sine-1000-6sec-60fps-320x240.mp4')
ffprobe -v quiet -i spec/support/assets/green-red_frame-20-sine-1000-6sec-60fps-320x240.mp4 -print_format json -show_format -show_streams

ffmpeg -y -filter_complex 'color=c=red:r=60:d=6:s=320x240 [red]; color=c=green:r=60:d=6:s=280x200 [green]; [red] [green] overlay=20:20; sine=1000:d=6' -s 320x240 spec/support/assets/green-red_frame-20-sine-1000-6sec-60fps-320x240.mp4
ffmpeg -y -filter_complex 'color=c=red:r=30:d=6:s=320x240 [red]; color=c=green:r=30:d=6:s=280x200 [green]; [red] [green] overlay=20:20' -r 30 spec/support/assets/green-red_frame-20-6sec-30fps-320x240.flv
ffmpeg -y -filter_complex 'sine=1000:d=6' spec/support/assets/sine-1000-6sec.mp3

XXX try and use movie filter

ffmpeg -y -filter_complex 'color=c=red:r=60:d=2 [red]; color=c=orange:r=60:d=2 [orange]; color=c=yellow:r=60:d=2 [yellow]; color=c=green:r=60:d=2 [green]; color=c=blue:r=60:d=2 [blue]; color=c=indigo:r=60:d=2 [indigo]; color=c=violet:r=60:d=2 [violet]; sine=1046.50:d=2 [c6]; sine=1174.66:d=2 [d6]; sine=1318.51:d=2 [e6]; sine=1396.91:d=2 [f6]; sine=1567.98:d=2 [g6]; sine=1760.00:d=2 [a6]; sine=1975.53:d=2 [b6]; [red] [c6] [orange] [d6] [yellow] [e6] [green] [f6] [blue] [g6] [indigo] [a6] [violet] [b6] concat=7:v=1:a=1' -s 320x240 spec/support/assets/rainbow-octave-14sec-60fps-320x240.mp4

XXX

ffmpeg -y -i ../workflows-service/spec/support/assets/videos/big_normal.mp4 -filter_complex "[0] trim=5:9, setpts=PTS-STARTPTS [o1]; [0] trim=9:11, setpts=PTS-STARTPTS [o2]; [0] trim=15:19, setpts=PTS-STARTPTS [o3]" -map "[o1]" /tmp/bubu_1a.y4m -map "[o2]" /tmp/bubu_1b.y4m -map "[o3]" /tmp/bubu_2.y4m

ffmpeg -y -i /tmp/bubu_1b-b.y4m -i /tmp/bubu_2-b.y4m -filter_complex "color=white:s=1280x720 [wt1]; [0] [wt1] alphamerge [ta1]; [ta1] fade=out:d=2:alpha=1 [fo1]; [1] [fo1] overlay" /tmp/bubu_2_1.y4m

ffmpeg -y -loglevel debug -i /tmp/bubu_1a-b.y4m -i /tmp/bubu_2_1.y4m -filter_complex "concat=2" /tmp/bubu-1-2.mp4

./buffer.rb 1000001 < /tmp/bubu_1a.y4m > /tmp/bubu_1a-b.y4m
./buffer.rb 1000000 < /tmp/bubu_1b.y4m > /tmp/bubu_1b-b.y4m
./buffer.rb 1000000 < /tmp/bubu_2.y4m > /tmp/bubu_2-b.y4m


ffmpeg -y -i ../workflows-service/spec/support/assets/videos/big_normal.mp4  -filter_complex "[0:v] trim=5:9, setpts=PTS-STARTPTS [o1:v]; [0:v] trim=9:11, setpts=PTS-STARTPTS [o2:v]; [0:v] trim=15:19, setpts=PTS-STARTPTS [o3:v]; [0:a] atrim=5:9, asetpts=PTS-STARTPTS [o1:a]; [0:a] atrim=9:11, asetpts=PTS-STARTPTS [o2:a]; [0:a] atrim=15:19, asetpts=PTS-STARTPTS [o3:a]; color=white:s=1280x720 [wt1]; [o2:v] [wt1] alphamerge [ta1:v]; [ta1:v] fade=out:d=2:alpha=1 [fo1:v]; [o2:a] afade=out:d=2 [fo1:a]; [o3:a] afade=in:d=2 [fi2:a]; [o3:v] [fo1:v] overlay [pt2:v]; [fi2:a] [fo1:a] amix [pt2:a]; [o1:v] [o1:a] [pt2:v] [pt2:a] concat=v=1:a=1" /tmp/bubu-1-2.mp4

ffmpeg -y -i /tmp/IMG_1248.MOV  -filter_complex "[0:v] split [i0a:v] [i0b:v]; [0:a] asplit [i0a:a] [i0b:a]; [i0a:v] trim=800:900, setpts=PTS-STARTPTS [o1:v]; [i0a:v] trim=900:901, setpts=PTS-STARTPTS [o2:v]; [i0b:v] trim=100:200, setpts=PTS-STARTPTS [o3:v]; [i0a:a] atrim=800:900, asetpts=PTS-STARTPTS [o1:a]; [i0a:a] atrim=900:901, asetpts=PTS-STARTPTS [o2:a]; [i0b:a] atrim=100:200, asetpts=PTS-STARTPTS [o3:a]; color=white:s=1920x1080 [wt1]; [o2:v] [wt1] alphamerge [ta1:v]; [ta1:v] fade=out:d=1:alpha=1 [fo1:v]; [o2:a] afade=out:d=1 [fo1:a]; [o3:a] afade=in:d=2 [fi2:a]; [o3:v] [fo1:v] overlay [pt2:v]; [fi2:a] [fo1:a] amix [pt2:a]; [o1:v] [o1:a] [pt2:v] [pt2:a] concat=v=1:a=1" /tmp/bubu-1-2.mp4

ffmpeg -y -i /tmp/IMG_1248.MOV  -filter_complex "[0:v] trim=890:900, setpts=PTS-STARTPTS [o1:v]; [0:v] trim=900:901, setpts=PTS-STARTPTS [o2:v]; [0:v] trim=100:110, setpts=PTS-STARTPTS [o3:v]; [0:a] atrim=890:900, asetpts=PTS-STARTPTS [o1:a]; [0:a] atrim=900:901, asetpts=PTS-STARTPTS [o2:a]; [0:a] atrim=100:110, asetpts=PTS-STARTPTS [o3:a]; color=white:s=1920x1080 [wt1]; [o2:v] [wt1] alphamerge, fade=out:d=1:alpha=1 [fo2:v]; [o2:a] afade=out:d=1 [fo2:a]; [o3:a] afade=in:d=1 [fi3:a]; [o3:v] [fo2:v] overlay [pt2:v]; [fi3:a] [fo2:a] amix [pt2:a]; [o1:v] [o1:a] [pt2:v] [pt2:a] concat=v=1:a=1" /tmp/bubu-1-2.mp4

Ffmprb.process(Ffmprb::File.open('/tmp/IMG_1248.MOV'), Ffmprb::File.create('/tmp/bubu.mp4')) do |input1, output1|

  in1 = input(input1)
  output(output1, resolution: Ffmprb::QVGA) do
    roll in1.cut(from: 890, to: 901)
    roll in1.cut(from: 1000, to: 1010), after: 10, transition: {blend: 1}
  end

end

Ffmprb.process(Ffmprb::File.open('spec/support/assets/green-red_frame-20-sine-1000-6sec-60fps-320x240.mp4'), Ffmprb::File.open('spec/support/assets/rainbow-octave-14sec-60fps-320x240.mp4'), Ffmprb::File.create('/tmp/bubu.mp4')) do |input1, input2, output1|

  in1, in2 = input(input1), input(input2)
  output(output1, resolution: Ffmprb::QVGA) do
    roll in1, transition: {blend: 1}
    roll in2, after: 3, transition: {blend: 1}
  end

end

ffmpeg -y -i /tmp/IMG_1248.MO -i /Users/showbox/proj/ffmprb/spec/support/assets/rainbow-octave-14sec-60fps-320x240.mp4 -filter_complex '[0:v] copy [cpsp0:v]; [0:a] anull [cpsp0:a]; [cpsp0:v] crop=x=in_w*0.25:y=in_h*0.25:w=in_w*0.5:h=in_h*0.5 [sp0:v]; [cpsp0:a] anull [sp0:a]; [sp0:v] scale=iw*min(320/iw\,240/ih):ih*min(320/iw\,240/ih), pad=320:240:(320-iw*min(320/iw\,240/ih))/2:(240-ih*min(320/iw\,240/ih))/2 [rl0:v]; [sp0:a] anull [rl0:a]; color=black:d=2.0:s=320x240 [bl0:v]; aevalsrc=0:d=2.0 [bl0:a]; [bl0:v] trim=0:3.0, setpts=PTS-STARTPTS [tm0b:v]; [bl0:a] atrim=0:2.0, asetpts=PTS-STARTPTS [tm0b:a]; color=white:d=3.0:s=320x240 [rn70322327791160:v]; [tm0b:v] [rn70322327791160:v] alphamerge, fade=out:d=2.0:alpha=1 [xrn70322327791160:v]; [rl0:v] [xrn70322327791160:v] overlay=x=0:y=0:eof_action=pass [tn0:v]; [tm0b:a] afade=out:d=2.0 [rn70322327791160:a]; [rl0:a] afade=in:d=2.0 [xrn70322327791160:a]; [rn70322327791160:a] [xrn70322327791160:a] amix=2 [tn0:a]; [1:v] copy [sp1:v]; [1:a] anull [sp1:a]; [sp1:v] scale=iw*min(320/iw\,240/ih):ih*min(320/iw\,240/ih), pad=320:240:(320-iw*min(320/iw\,240/ih))/2:(240-ih*min(320/iw\,240/ih))/2 [rl1:v]; [sp1:a] anull [rl1:a]; color=black:d=5.0:s=320x240 [bltn01:v]; aevalsrc=0:d=5.0 [bltn01:a]; [tn0:v] [bltn01:v] concat=2:v=1:a=0 [pdtn01:v]; [tn0:a] [bltn01:a] concat=2:v=0:a=1 [pdtn01:a]; [pdtn01:v] split [pdtn01a:v] [pdtn01b:v]; [pdtn01:a] asplit [pdtn01a:a] [pdtn01b:a]; [pdtn01a:v] trim=0:3, setpts=PTS-STARTPTS [tmtn01a:v]; [pdtn01a:a] atrim=0:3, asetpts=PTS-STARTPTS [tmtn01a:a]; [pdtn01b:v] trim=2:6.0, setpts=PTS-STARTPTS [tm1b:v]; [pdtn01b:a] atrim=2:6.0, asetpts=PTS-STARTPTS [tm1b:a]; color=white:d=4.0:s=320x240 [rn70322330676860:v]; [tm1b:v] [rn70322330676860:v] alphamerge [dbg1:v]; [dbg1:v] split [dbg:v] [dbg2:v]; [dbg2:v] fade=out:d=2.0:alpha=1 [xrn70322330676860:v]; [rl1:v] [xrn70322330676860:v] overlay=x=0:y=0:eof_action=pass [tn1:v]; [tm1b:a] afade=out:d=2.0 [rn70322330676860:a]; [rl1:a] afade=in:d=2.0 [xrn70322330676860:a]; [rn70322330676860:a] [xrn70322330676860:a] amix=2 [tn1:a]; [tmtn01a:v] [tmtn01a:a] [tn1:v] [tn1:a] concat=2:v=1:a=1' -s 320x240 /tmp/bubu.mp4 -map ['dbg:v'] /tmp/bubua.mp4



## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/ffmprb/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
