require 'digest/md5'
require 'mini_magick'
require 'exifr' # read exif metadata for orientation et al

module Jekyll
  module GalleryGenerator
    # TODO: :dst dokumentieren, bzw über to_<formats> aufrufe unterschiedliche daten 
    #  an unterschiedliche zielformate binden:
    #  - to_liquid für nur im template relevante attribute
    #  - to_json für nur im auslgelieferten json für die Frontend Apps
    #
    class Image

      attr_reader :src, :dst, :presets, :index, :digest, :exif, :quality

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
          :path => src_path,
          :basepath => gallery.src[:basepath],
          :filename => File.basename(src_path),
          :ext      => ext,
          :filename_base => File.basename(src_path, ext)
        }
        @dst = {
          :basepath => gallery.dst[:basepath],
          :baseurl => gallery.dst[:baseurl]
        }
        @quality = gallery.quality
        @presets = gallery.presets
        @presets.each do |preset_key, preset|
          @dst[preset_key] = {}
        end
        @generate = @regenerate_images = gallery.regenerate_images?
        @index = opts['index']
      end

      # This works, after Gallery#read_images and fills the instance vars for a
      # correct Image#to_json, without having to run Image#generate_presets
      def read_json!(json_hash)
        @digest = json_hash['digest']
        @index = json_hash['index']
        @exif = json_hash['exif']
        @presets.each do |preset_key, preset|
          @dst[preset_key][:url] = File.join(preset[:baseurl], json_hash['filename'])
          @dst[preset_key][:baseurl] = preset[:baseurl]
          @dst[preset_key][:width] = json_hash[preset_key]['width']
          @dst[preset_key][:height] = json_hash[preset_key]['height']
        end
        @dst[:filename] = json_hash['filename']
        @src[:ratio] = json_hash['ratio']
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
        json = {
          'digest'        => @digest,
          'index'         => @index,
          'filename'      => @dst[:filename],
          'orientation'   => @src[:ratio] <= 1 ? 'portrait' : 'landscape',
          'ratio'         => @src[:ratio],
          'exif'          => @exif
        }.merge(preset_urls)
      end
      
      def to_liquid
        to_h
      end
      
      def get_preset_attrs(including_src)
        @presets.keys.inject({}) do |p_urls, p_key|
          p_urls[p_key] = {
            :width => @dst[p_key][:width].to_i,
            :height => @dst[p_key][:height].to_i
          }
          p_urls[p_key][:src] = @dst[p_key][:url] if including_src
          p_urls
        end
      end
              
      # Check for all presets in @dst['basepath']
      # Fills dst Hash (so wie in #to_json ausgegeben), wenn Files schon 
      # vorhanden, ansonsten muss das src-File ja gelesen und der digest noch 
      # berechnet werden...
      #
      # if we do not have all dst images || @regenerate_images => @generate = true
      def generate?
        pattern = File.join(
          @dst[:basepath], "{#{presets.keys.join(',')}}", "#{@src[:filename_base]}-*#{@src[:ext]}"
        )
        @generate ||= Dir.glob(pattern).size < @presets.keys.size
      end
      
      def generate_presets
        LOG.info "Reading in Image #{@src[:path]} ..."
        image = MiniMagick::Image.open(@src[:path])
        # Save orig-Image-Blob for later use of orig Image
        @src[:image_blob] = image.to_blob
        @digest = Digest::MD5.hexdigest(@src[:image_blob]).slice!(0..5)
        @dst[:filename] = "#{@src[:filename_base]}-#{@digest}#{@src[:ext]}"
        
        # Read Exif Data
        begin
          exif_reader = EXIFR::JPEG.new(StringIO.new(@src[:image_blob]))
          
          # Puto EXIF orientation ghetto:
          # http://www.daveperrett.com/articles/2012/07/28/exif-orientation-handling-is-a-ghetto/
          # Hack, wenn die Orientation nicht TopLeft ist, dann entsprechend 
          # drehen und exif neu auslesen.
          orientation = exif_reader.orientation
          LOG.debug "Orientation? #{orientation.inspect}"
          if (orientation && orientation.to_i > 1) # 1 => TopLeft => everything OK
            image.auto_orient
            @src[:image_blob] = image.to_blob
            exif_reader = EXIFR::JPEG.new(StringIO.new(@src[:image_blob]))
          end
          
          @exif = exif_reader.exif.to_hash
        rescue
          # puts "Error when trying to read EXif data... continue without".red
          @exif = nil
        end
        
        @src[:width] = image[:width].to_f
        @src[:height] = image[:height].to_f
        @src[:ratio] = @src[:width]/@src[:height]
        # DEBUG
        # LOG.debug "src: #{@src[:width]}x#{@src[:height]} (#{@src[:ratio]})"
        
        @presets.each do |preset_key, preset|
          write_preset preset_key, preset
        end
        
        # Free memory!
        image.destroy!
        @src.delete :image_blob
      end
      
      # set and genrate resized images
      def write_preset preset_key, preset
        # Set dest path <basepath>/<preset_key>/<filename>-<digest><ext>
        dst_dir = @dst[preset_key][:dir] = File.join(@dst[:basepath], preset_key)
        dst_path = @dst[preset_key][:path] = File.join(dst_dir, @dst[:filename])
        dst_baseurl = @dst[preset_key][:baseurl] = File.join(@dst[:baseurl], preset_key)
        @dst[preset_key][:url] = File.join(dst_baseurl, @dst[:filename])
        
        # Calculate preset dimensions
        calculate_preset_dims(preset_key, preset)
        
        if !File.exists?(dst_path) || @regenerate_images
          # Reading in Image again (from blob => no File-System reading again)
          image = MiniMagick::Image.read(@src[:image_blob])
          
          #  If the destination directory doesn't exist, create it
          FileUtils.mkdir_p(dst_dir) unless File.exist?(dst_dir)
                      
          # Let people know their images are being generated
          LOG.info "Generating #{dst_path}"
          
          # Scale and crop
          image.combine_options do |i|
            i.resize "#{@dst[preset_key][:width]}x#{@dst[preset_key][:height]}^"
            i.gravity "center"
            i.quality @quality
          end

          # write new image file 
          image.write dst_path
          
          # free memory
          image.destroy!
        else
          LOG.info 'Nothing to generate all files are there yet!'
        end
      end
      
      def calculate_preset_dims preset_key, preset
        # calculate dimensions of preset
        orig_width = @src[:width]; orig_height = @src[:height]
        orig_ratio = @src[:ratio]
        LOG.info "preset: #{preset_key}"
        @dst[preset_key][:width] = gen_width = if preset['width']
          preset['width'].to_f
        elsif preset['height']
          orig_ratio * preset['height'].to_f
        else
          orig_width
        end
        @dst[preset_key][:height] = gen_height = if preset['height']
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
          @dst[preset_key][:width] = gen_width = if orig_ratio < gen_ratio then orig_width else orig_height*gen_ratio end
          @dst[preset_key][:height] = gen_height = if orig_ratio > gen_ratio then orig_height else orig_width/gen_ratio end
        end
        
        LOG.warn "Warning:".yellow + " #{@src[:filename]} is smaller than the requested output file. It will be resized without upscaling." if undersize
      end
    end
  end
end
