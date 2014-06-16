# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'jekyll_gallery_generator/version'

Gem::Specification.new do |s|
  s.name        = 'jekyll_gallery_generator'
  s.version     = Jekyll::GalleryGenerator::VERSION
  s.platform   = Gem::Platform::RUBY
  s.homepage    =
    'https://github.com/snrbrnjna/jekyll-gallery-generaor'
  s.summary     = 'Jekyll Gallery Generator Plugin'
  s.description = 'A Jekyll Plugin for nice responsive galleries.'
  s.authors     = ["snr brnjna"]
  s.email       = 'snr@brnjna.net'

  s.add_runtime_dependency 'jekyll', '~> 1.5'
  s.add_runtime_dependency 'mini_magick', '~> 3.7'
  s.add_runtime_dependency 'exifr', '~> 1.1'
  s.add_runtime_dependency 'ruby-progressbar', '~> 1.4'
  
  s.add_development_dependency 'debugger'
  
  s.files       = [
    'lib/jekyll_gallery_generator.rb',
    'lib/jekyll_gallery_generator/filter.rb',
    'lib/jekyll_gallery_generator/gallery.rb',
    'lib/jekyll_gallery_generator/generator.rb',
    'lib/jekyll_gallery_generator/image.rb',
    'lib/jekyll_gallery_generator/processors.rb'
  ]

  s.require_paths = ['lib']

  s.license       = 'modified MIT'
end
