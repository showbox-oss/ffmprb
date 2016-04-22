# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ffmprb/version'

Gem::Specification.new do |spec|
  spec.name          = 'ffmprb'
  spec.version       = Ffmprb::VERSION
  spec.authors       = ["showbox.com", "Costa Shapiro"]
  spec.email         = ['costa@mouldwarp.com']

  spec.summary       = "ffmprb is your audio/video montage friend, based on https://ffmpeg.org"
  spec.description   = "A video and audio composing DSL (Damn-Simple Language) and a micro-engine for ffmpeg and ffriends"
  spec.homepage      = Ffmprb::GEM_GITHUB_URL

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # NOTE I'm not happy with this dependency, and there's nothing crossplatform (= for windoze too) at the moment
  spec.add_dependency 'mkfifo', '~> 0.1.1'
  # NOTE make it into an optional dependency? Nah for now
  spec.add_dependency 'thor', '~> 0.19.1'

  spec.add_development_dependency 'bundler', '>= 1.11.2'
  spec.add_development_dependency 'byebug', '>= 8.2.4'
  spec.add_development_dependency 'simplecov', '>= 0.11.2'
  spec.add_development_dependency 'guard-rspec', '>= 4.6.5'
  spec.add_development_dependency 'guard-bundler', '>= 2.1.0'
  spec.add_development_dependency 'rake', '>= 11.1.2'
  spec.add_development_dependency 'rmagick', '>= 2.15.4'
  spec.add_development_dependency 'ruby-sox', '>= 0.0.3'
  spec.add_development_dependency 'firebase', '>= 0.2.6'

  spec.post_install_message = "Have fun with your montage! To enable proc visualisation, install firebase gem and set FFMPRB_PROC_VIS_FIREBASE env."  unless Ffmprb::FIREBASE_AVAILABLE
end
