# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ffmprb/version'

Gem::Specification.new do |spec|
  spec.name          = 'ffmprb'
  spec.version       = Ffmprb::VERSION
  spec.authors       = ["showbox.com", "Costa Shapiro @ Showbox"]
  spec.email         = ['costa@showbox.com']

  spec.summary       = "ffmprb is your audio/video montage friend, based on https://ffmpeg.org"
  spec.description   = "A DSL (Damn-Simple Language) and a micro-engine for ffmpeg and ffriends"
  spec.homepage      = 'https://github.com/showbox-oss/ffmprb'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # NOTE I'm not happy with this dependency, and there's nothing crossplatform (= for windoze too) at the moment
  spec.add_dependency 'mkfifo'

  spec.add_development_dependency 'bundler', '>= 1.9.9'
  spec.add_development_dependency 'byebug', '>= 4.0.5'
  spec.add_development_dependency 'guard-rspec', '>= 2.12.8'
  spec.add_development_dependency 'rake', '>= 10.4.2'
  spec.add_development_dependency 'rmagick', '>= 2.15'
  spec.add_development_dependency 'rspec', '>= 3.2.0'
  spec.add_development_dependency 'ruby-sox', '>= 0.0.3'
end
