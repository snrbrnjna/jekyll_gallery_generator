module Jekyll
  module Processors
    NOTHING = lambda do |generator, gallery|
      puts "... nothing to do"

      data = generator.parse_json(gallery)
      gallery.read_json(data)
      return :nothing
    end

    CHECK_IMAGES = lambda do |generator, gallery|
      puts "... check_images"
      return NOTHING.call(generator, gallery) if gallery.processed?

      gallery.read_origs
      data = generator.parse_json(gallery)
      if (data && gallery.check_images(data))
        gallery.read_json(data)
        return :nothing
      else
        gallery.generate_presets(false)
        return :'check_images'
      end
    end

    GENERATE_DATA = lambda do |generator, gallery|
      puts "... generate_data"
      return NOTHING.call(generator, gallery) if gallery.processed?

      gallery.read_origs
      gallery.generate_presets(false)
      return :generate_data
    end

    GENERATE_IMAGES = lambda do |generator, gallery|
      return NOTHING.call(generator, gallery) if gallery.processed?
      puts "... generate_images"
      
      gallery.read_origs
      gallery.generate_presets(true)
      return :generate_images
    end
  end
end
