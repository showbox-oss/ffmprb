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

ffmpeg -y -filter_complex 'color=c=red:r=60:d=6, scale=320x240 [red]; color=c=green:r=60:d=6, scale=280x200 [green]; [red] [green] overlay=20:20; sine=1000:d=6' -s 320x240 spec/support/assets/green-red_frame-20-sine-1000-6sec-60fps-320x240.mp4

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/ffmprb/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
