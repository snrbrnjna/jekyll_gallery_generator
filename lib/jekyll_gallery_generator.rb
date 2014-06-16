require 'fileutils'
require 'json'
require 'logger'

require_relative './jekyll_gallery_generator/gallery'
require_relative './jekyll_gallery_generator/image'
require_relative './jekyll_gallery_generator/processors'
require_relative './jekyll_gallery_generator/generator'
require_relative './jekyll_gallery_generator/filter'

# DEBUG
# require 'debugger'

module Jekyll
  module GalleryGenerator

    # Open Log-File
    # logfile has to be outside of jekyll root, else an entry in the log triggers
    # a rebuild of the site, when startet with directory watcher
    logfile = '/tmp/jekyll_log/gallery.log'
    FileUtils.mkdir_p File.dirname(logfile) unless File.exists?(File.dirname(logfile))
    # maximum of 10MB and 10 old versions kept
    LOG = Logger.new(logfile, 10, 1024000)

    # register Filters
    Liquid::Template.register_filter(Jekyll::GalleryGenerator::Filter)

  end
end

class Numeric
  def to_human
    units = %w{Byte KB MB GB TB}
    e = self > 0 ? (Math.log(self)/Math.log(1024)).floor : 0
    s = (e>2 ? "%.3f" : "%.0f") % (to_f / 1024**e)
    s + " #{units[e]}"
  end
end
