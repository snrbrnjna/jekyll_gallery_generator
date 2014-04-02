# encoding: UTF-8

require 'ruby-progressbar'

module Jekyll
  module GalleryGenerator
    class Gallery
      
      EXT_PATTERN = '*.{JPG,JPEG,jpg,png}'
      DEFAULTS = {
        'title' => '',
        'presets' => {
          'thumb' => {
            'width' => 300,
            'base_url' => ''
          },
          'large' => {
            'width' => 800,
            'base_url' => ''
          }
        },
        'regenerate_images' => false,
        'generate_gallery' => false,
        'dynamic_fill' => true,
        'quality' => 100,
        'gallery' => {
          'min_col_width' => {
            'desktop' => 320,
            'pads' => 320,
            'phones' => 300
          },
          'gutter_width' => 3,
          'chunk_size' => 8,
          'first_chunk' => 15
        }
      }
      
      attr_accessor :dst, :size
      attr_reader :title, :project, :src, :presets, :images, :quality, :opts
      
      def initialize site, project, opts
        LOG.info("Processing Gallery '#{project}' ...")
        puts "Processing Gallery '#{project}' ..."
        # defaults (CAUTION: this is no deep merge!)
        opts = {}.merge(DEFAULTS).merge(opts)

        # Invaild Presets?
        raise ArgumentError.new(
          "Gallery #{project} can't be created because of invalid presets: #{opts['presets']}"
        ) unless valid_opts?(opts)            

        # Fill instance vars
        @site_base = site.source
        @title = opts['title']
        @project = project
        @src = {
          :basepath => File.join(@site_base, site.config['gallery']['src']['basepath'], @project)
        }
        @dst = {
          :basepath => File.join(@site_base, site.config['gallery']['dst']['basepath'], @project),
          :baseurl => File.join(site.config['gallery']['dst']['baseurl'], @project)
        }
        @presets = set_presets(opts)
        @quality = opts['quality']
        
        # prepare other instance vars
        @src[:image_paths] = []
        @images = []
        @size = 0 # filesize
        
        # if opts['generate_gallery'] => write json and galery_post
        # if opts['regenerate_images'] => override old presets
        @regenerate_images = opts['regenerate_images'] 
        @generate = @regenerate_images || opts['generate_gallery']
        
        @dynamic = opts['dynamic_fill']
        # options to configure the javascript Gallery
        @opts = opts['gallery']
      end
      
      # presets Hash has to contain a thumb and a large preset
      def valid_opts?(opts)
        opts.has_key?('presets') && 
          opts['presets'].has_key?('thumb') &&
          opts['presets'].has_key?('large') &&
          (
            opts['presets']['thumb'].has_key?('width') ||
            opts['presets']['thumb'].has_key?('height')
          ) &&
          (
            opts['presets']['large'].has_key?('width') ||
            opts['presets']['large'].has_key?('height')
          )
      end
      
      # sets all preset attributes from the opts Hash and sets the baseurl for
      # every preset
      def set_presets(opts)
        @presets = opts['presets']
        @presets.each do |p_key, preset|
          preset[:baseurl] = File.join(@dst[:baseurl], p_key)
        end
      end
      
      # This works, after Gallery#read_images and fills the Image 
      # instance vars for a correct Image#to_json, without having to 
      # run Gallery#generate_presets
      def read_json!(json_path)
        io = IO.read(json_path)
        begin
          json_hash = JSON.parse(io)
        rescue
          raise Exception.new("Corrupt Json File #{json_path}. Delete it and try again!")
        end
        @title = json_hash['gallery']['title']
        set_presets(json_hash['gallery'])
        json_images = json_hash['gallery']['images']
        if (json_images.size != @images.size)
          raise Exception.new("Corrupt Json File #{json_path}. Delete it and try again!")
        end
        json_images.each do |json_img|
          @images[json_img['index']].read_json!(json_img)
        end
      end
              
      def to_liquid
        # opts has to be a json string in the liquid var
        hash = to_h; hash['opts'] = hash['opts'].to_json
        hash
      end
      
      def to_json(*a)
        to_h.to_json(*a)
      end
      
      def to_h
        {
          'title'         => @title,
          'project'       => @project,
          'presets'       => @presets,
          'imageCount'    => @images.size,
          'images'        => @images,
          'dynamic'       => @dynamic,
          'opts'          => @opts
        }
      end
      
      # Create Image objects and checks if all presets are generated yet
      def read_images
        raise "Directory with fullsize images doesn't exist: #{@src[:basepath]}" unless Dir.exists?(@src[:basepath])
        # Read in sources
        @src[:image_paths] = Dir[File.join(@src[:basepath], EXT_PATTERN)]
        # normalize filenames
        normalize_basenames!
        @src[:image_paths].each_with_index do |src_path, idx|
          @images << img = Jekyll::GalleryGenerator::Image.new(self, src_path, 
            'index' => idx
          )
          # if we miss 1 dst image => all have to be read-in for the json file to be rewritten
          @generate ||= img.generate?
        end
      end
      
      # Private method!
      # Renames src Files if they have spaces in the Filename or if its
      # starts with an underscore, so that jekyll won't copy them.
      #
      # To exclude the generated files from uploading prefix the dest[:base_dir]
      # with an underscore.
      def normalize_basenames!
        @src[:image_paths].map! do |path|
          dirname = File.dirname(path)
          basename = File.basename(path)
          basename.gsub!(/&|;|,|\s/, '_')
          basename.gsub!(/^_/, '')
          basename.gsub!(/_+/, '_')
          # Dirty kranky shit! Fuck unicode! 3 hours of dead research led me
          # to this ill shit: MAC Filenames are stored in a somwhat different
          # utf8 encoding than utf8. Shit! Have to encode (transliterate)
          # it to UTF-8 and then i can replace umlauts et all...
          # don't have a look for more infos at https://www.ruby-forum.com/topic/4407424
          basename.encode!('UTF-8','UTF-8-MAC').tr!(
          "ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčÐðĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšſŢţŤťŦŧÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž",
          "AAAAAAaaaaaaAaAaAaCcCcCcCcCcDdDdDdEEEEeeeeEeEeEeEeEeGgGgGgGgHhHhIIIIiiiiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnNnnNnOOOOOOooooooOoOoOoRrRrRrSsSsSsSssTtTtTtUUUUuuuuUuUuUuUuUuUuWwYyyYyYZzZzZz")
          basename.gsub!(/ß/,'ss')
          unless basename == File.basename(path)
            File.rename(path, File.join(dirname, basename))
          end
          File.join(dirname, basename)
        end
      end
      
      # all have to be read in as a minimum requirement 
      # => json file with metadata has to be created again
      # => html files have to be created with all thumbs in it
      def generate?
        @generate
      end
      
      # all images have to be regenerated
      def regenerate_images?
        @regenerate_images
      end
      
      # Generate resized images
      def generate_presets
        # Initialize Progressbar (# images * presets + 1)
        progressbar = ProgressBar.create(:format => '%a |%b>>%i| %p%% %t', 
          :total => @images.size)
        @images.each do |img|
          img.generate_presets
          progressbar.increment
        end
      end
    end
  end
end
