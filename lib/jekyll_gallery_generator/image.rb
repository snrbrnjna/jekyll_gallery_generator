require 'digest/md5'
require 'mini_magick'
require 'exifr' # read exif metadata for orientation et al

module Jekyll
  module GalleryGenerator

    # Image Page written next to the Gallery posts.
    class ImagePage < Page
      def initialize(site, base, dir, image, gallery)
        @site = site
        @base = base
        @dir = dir
        @name = "index.html"

        # do the stuff jekyll needs to do for pages
        self.process(@name)

        # check the image page layout
        layout_path = File.join(base, '_layouts', 'gallery_image.html')
        raise "File not found: #{layout_path}" unless File.exists?(layout_path)

        # read in the layout yaml front matter
        self.read_yaml(File.dirname(layout_path), File.basename(layout_path))

        # pass image and gallery hashes for liquid usage in the layout file
        self.data['image'] = image
        self.data['gallery'] = gallery
      end
    end

    # TODO: :dst dokumentieren, bzw über to_<formats> aufrufe unterschiedliche daten 
    #  an unterschiedliche zielformate binden:
    #  - to_liquid für nur im template relevante attribute
    #  - to_json für nur im auslgelieferten json für die Frontend Apps
    #
    class Image

      attr_reader :src, :dst, :presets, :index, :digest, :exif, :quality

      META_DEFAULT = {'title' => '', 'tags' => ''}

      # TODO: validate File-Extensions
      def initialize gallery, src_path, opts
        
        # defaults
        opts = {}.merge({
          'index' => -1
        }).merge(opts)
        
        # Fill instance vars
        @project = gallery.project
        ext = File.extname(src_path)
        @src = {
          'path' => src_path,
          'basepath' => gallery.src['basepath'],
          'filename' => File.basename(src_path),
          'ext'      => ext,
          'filename_base' => File.basename(src_path, ext)
        }
        @dst = {
          'basepath' => gallery.dst['basepath'],
          'baseurl' => gallery.dst['baseurl']
        }
        @quality = gallery.quality
        @presets = gallery.presets
        @presets.each do |preset_key, preset|
          @dst[preset_key] = {}
        end
        @index = opts['index']
      end

      def title
        @title ||= @meta['title'] || meta['filename']
      end

      # Fills the instance vars for a correct Image#to_json, without having to 
      # run Image#generate_presets
      # CAUTION: #presets have to be set yet! Leaves #src Hash as is.
      def read_json(json_hash)
        @digest = json_hash['digest']
        @index = json_hash['index']
        @exif = json_hash['exif']
        @presets.each do |preset_key, preset|
          @dst[preset_key]['url'] = File.join(preset['baseurl'], json_hash['filename'])
          @dst[preset_key]['baseurl'] = preset['baseurl']
          @dst[preset_key]['width'] = json_hash[preset_key]['width']
          @dst[preset_key]['height'] = json_hash[preset_key]['height']
        end
        @dst['filename'] = json_hash['filename']
        @src['ratio'] = json_hash['ratio']
      end

      def set_meta(data)
        @meta = {'filename' => @src['filename']}.merge(META_DEFAULT).merge(data || {})
      end
      
      def to_json(*a)
        begin
          to_h.to_json(*a)
        rescue
          puts to_h
        end
      end
      
      def to_h
        preset_urls = get_preset_attrs(false)
        # BUGFIX: some cameras give NaN values into their exif-data
        # => don't save these keys in json
        @exif && @exif.reject!{|k,v| v.respond_to?('nan?') && v.nan? }
        {
          'digest'        => @digest,
          'index'         => @index,
          'filename'      => @dst['filename'],
          'orientation'   => @src['ratio'] <= 1 ? 'portrait' : 'landscape',
          'ratio'         => @src['ratio'],
          'exif'          => @exif,
          'meta'          => @meta
        }.merge(preset_urls)
      end
      
      def to_liquid
        to_h
      end
      
      # Check for all presets in @dst['basepath']
      # Fills dst Hash (so wie in #to_json ausgegeben), wenn Files schon 
      # vorhanden, ansonsten muss das src-File ja gelesen und der digest noch 
      # berechnet werden...
      #
      # if we do not have all dst images
      def presets_generated?
        pattern = File.join(
          @dst['basepath'], "{#{presets.keys.join(',')}}", "#{@src['filename_base']}-*#{@src['ext']}"
        )
        Dir.glob(pattern).size == @presets.keys.size
      end
      
      def generate_presets(force)
        image = read_src_image()

        @presets.each do |preset_key, preset|
          # prepare preset dst infos
          prepare_preset_dst(preset_key, preset)
          
          # Calculate preset dimensions
          calculate_preset_dims(preset_key, preset) 

          if force || !File.exists?(@dst[preset_key]['path'])
            write_preset(preset_key, preset)
          else
            LOG.info 'Nothing to generate all files are there yet!'
          end
        end
        
        # Free memory!
        image.destroy!
        @src.delete 'image_blob'
      end

      # Generate a Html Page for the Image with metadata for sharing the Image on
      # Facebook or Twitter, etc. The page includes a JS-statement, which redirects 
      # the Browser to the Gallery Post with the image opened in the slider.
      def generate_redirect_page site, gallery
        basedir = gallery.post_path.gsub(/\.html$/, '')
        site.pages << ImagePage.new(
          site, 
          site.source, 
          File.join(basedir, @digest), 
          self,
          gallery
        )
      end
      
    private

      # Reads in src image file and calculates and sets its attributes
      def read_src_image

        LOG.info "Reading in Image #{@src['path']} ..."
        image = MiniMagick::Image.open(@src['path'])
        # Save orig-Image-Blob for later use of orig Image
        @src['image_blob'] = image.to_blob
        @digest = Digest::MD5.hexdigest(@src['image_blob']).slice!(0..5)
        @dst['filename'] = "#{@src['filename_base']}-#{@digest}#{@src['ext']}"
        
        # Read Exif Data
        begin
          exif_reader = EXIFR::JPEG.new(StringIO.new(@src['image_blob']))
          
          # Puto EXIF orientation ghetto:
          # http://www.daveperrett.com/articles/2012/07/28/exif-orientation-handling-is-a-ghetto/
          # Hack, wenn die Orientation nicht TopLeft ist, dann entsprechend 
          # drehen und exif neu auslesen.
          orientation = exif_reader.orientation
          LOG.debug "Orientation? #{orientation.inspect}"
          if (orientation && orientation.to_i > 1) # 1 => TopLeft => everything OK
            image.auto_orient
            @src['image_blob'] = image.to_blob
            exif_reader = EXIFR::JPEG.new(StringIO.new(@src['image_blob']))
          end
          
          @exif = exif_reader.exif.to_hash
        rescue
          # puts "Error when trying to read EXif data... continue without".red
          @exif = nil
        end
        
        @src['width'] = (image[:width] || image['width']).to_f
        @src['height'] = (image[:height] || image['height']).to_f
        @src['ratio'] = @src['width']/@src['height']

        return image
      end

      # returns Hash with attrs for all presets 
      def get_preset_attrs(including_src)
        @presets.keys.inject({}) do |p_urls, p_key|
          p_urls[p_key] = {
            'width'   => @dst[p_key]['width'].to_i,
            'height'  => @dst[p_key]['height'].to_i
          }
          p_urls[p_key]['src'] = @dst[p_key]['url'] if including_src
          p_urls
        end
      end

      # set and genrate resized images
      def write_preset preset_key, preset
        # Reading in Image again (from blob => no File-System reading again)
        image = MiniMagick::Image.read(@src['image_blob'])
        
        #  If the destination directory doesn't exist, create it
        FileUtils.mkdir_p(@dst[preset_key]['dir']) unless File.exist?(@dst[preset_key]['dir'])
                    
        # Let people know their images are being generated
        LOG.info "Generating #{@dst[preset_key]['path']}"
        
        # Scale and crop
        image.combine_options do |i|
          i.resize "#{@dst[preset_key]['width']}x#{@dst[preset_key]['height']}^"
          i.gravity "center"
          i.quality @quality
        end

        # write new image file 
        image.write @dst[preset_key]['path']
        
        # free memory
        image.destroy!
      end
      
      def calculate_preset_dims preset_key, preset
        # calculate dimensions of preset
        orig_width = @src['width']; orig_height = @src['height']
        orig_ratio = @src['ratio']
        LOG.info "preset: #{preset_key}"
        @dst[preset_key]['width'] = gen_width = if preset['width']
          preset['width'].to_f
        elsif preset['height']
          orig_ratio * preset['height'].to_f
        else
          orig_width
        end
        @dst[preset_key]['height'] = gen_height = if preset['height']
          preset['height'].to_f
        elsif preset['width']
          preset['width'].to_f / orig_ratio
        else
          orig_height
        end
        gen_ratio = gen_width/gen_height
        LOG.info "dest: #{gen_width}x#{gen_height} (#{gen_ratio})"

        # Don't allow upscaling. If the image is smaller than the requested dimensions, recalculate.
        if orig_width < gen_width || orig_height < gen_height
          undersize = true
          @dst[preset_key]['width'] = gen_width = if orig_ratio < gen_ratio then orig_width else orig_height*gen_ratio end
          @dst[preset_key]['height'] = gen_height = if orig_ratio > gen_ratio then orig_height else orig_width/gen_ratio end
        end
        
        LOG.warn "Warning:".yellow + " #{@src['filename']} is smaller than the requested output file. It will be resized without upscaling." if undersize
      end

      # set dst path infos for given preset
      def prepare_preset_dst preset_key, preset
        # Set dest path <basepath>/<preset_key>/<filename>-<digest><ext>
        @dst[preset_key]['dir'] = File.join(@dst['basepath'], preset_key)
        @dst[preset_key]['path'] = File.join(@dst[preset_key]['dir'], @dst['filename'])
        @dst[preset_key]['baseurl'] = File.join(@dst['baseurl'], preset_key)
        @dst[preset_key]['url'] = File.join(@dst[preset_key]['baseurl'], @dst['filename'])
      end
    end
  end
end
