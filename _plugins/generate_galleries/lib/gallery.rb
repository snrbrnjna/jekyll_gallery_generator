# encoding: UTF-8

require 'ruby-progressbar'

module Jekyll
  module GalleryGenerator
    class Gallery
      
      EXT_PATTERN = '*.{JPG,JPEG,jpg,png}'
      
      attr_accessor :dst
      attr_reader :title, :project, :src, :presets, :images, :quality, :opts, 
        :pretty_json
      
      def initialize site, title, config
        puts "Processing Gallery '#{config['project']}' ..."

        # Invaild Presets?
        raise ArgumentError.new(
          "Gallery #{config['project']} can't be created because of invalid presets: #{config['presets']}"
        ) unless valid_config?(config)            

        # Fill instance vars
        @site_base = site.source
        @title = title
        @project = config['project']
        @src = {
          :basepath => File.join(@site_base, config['src']['basepath'], @project)
        }
        @dst = {
          :basepath => File.join(@site_base, config['dst']['basepath'], @project),
          :baseurl => File.join(config['dst']['baseurl'], @project)
        }
        @presets = set_presets(config)
        @quality = config['quality']
        
        # prepare other instance vars
        @src[:image_paths] = []
        @images = []
        @size = 0 # filesize
        
        # TODO: if config['regenerate_images'] => override old presets
        # TODO: if config['generate_gallery'] => write json
        @regenerate_images = config['regenerate_images'] 
        @generate = @regenerate_images || config['generate_gallery']
        
        @dynamic = config['dynamic_fill']
        @pretty_json = config['pretty_json']
        @processed = false
        
        # options to configure the javascript Gallery
        @opts = config['opts']
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

      def processed!
        @processed = true
      end

      def processed?
        @processed
      end

      def remote?
        @dst[:baseurl].start_with?('http://', 'https://')
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

      def size
        if @size == 0
          @presets.each do |p_key, preset|
            dirname = File.join(@dst[:basepath], p_key)
            images = Dir.glob(File.join(dirname, '*'))
            summed_size = 0
            images.each do |img|
              summed_size += File.size(img)
            end
            @presets[p_key]['size'] = summed_size
            @size += summed_size
          end
        end
        @size
      end
      
    private

      # presets Hash has to contain a thumb and a large preset
      def valid_config?(config)
        config.has_key?('presets') && 
          config['presets'].has_key?('thumb') &&
          config['presets'].has_key?('large') &&
          (
            config['presets']['thumb'].has_key?('width') ||
            config['presets']['thumb'].has_key?('height')
          ) &&
          (
            config['presets']['large'].has_key?('width') ||
            config['presets']['large'].has_key?('height')
          )
      end
      
      # sets all preset attributes from the config Hash and sets the baseurl for
      # every preset
      def set_presets(config)
        @presets = config['presets']
        @presets.each do |p_key, preset|
          preset[:baseurl] = File.join(@dst[:baseurl], p_key)
        end
      end

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

    end
  end
end
