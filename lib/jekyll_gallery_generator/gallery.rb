# encoding: UTF-8

require 'ruby-progressbar'

module Jekyll
  module GalleryGenerator
    class Gallery
      
      EXT_PATTERN = '*.{JPG,JPEG,jpg,png}'
      POST_META_KEYS = %{title description categories tags author date}
      
      attr_accessor :dst, :image_meta_orig
      attr_reader :title, :project, :meta, :post_path, :post_basepath, :post_baseurl,
        :src, :presets, :quality, :images, :processor_action, :opts,
        :pretty_json, :image_meta, :image_pages
      
      def initialize site, title, post, config
        # Invaild Presets?
        raise ArgumentError.new(
          "Gallery #{config['project']} can't be created because of invalid presets: #{config['presets']}"
        ) unless valid_config?(config)            

        # Fill instance vars
        @site_base = site.source
        @title = title
        @meta = post.data.select {|k,v| POST_META_KEYS.include?(k)}
        @project = config['project']

        # Get path, basepath and url of gallery post
        @post_path = post.url
        # post.url returns "index-page" paths always without the trailing index.html
        @post_basepath = @post_path[/\.html$/] ? File.dirname(@post_path) : @post_path
        @post_baseurl = site.config['url']

        @src = {
          'basepath' => File.join(@site_base, config['src']['basepath'], @project)
        }
        @dst = {
          'basepath' => File.join(@site_base, config['dst']['basepath'], @project),
          'baseurl' => File.join(config['dst']['baseurl'], @project),
          'jsonpath' => File.join(@site_base, config['dst']['basepath'], "#{@project}.json"),
          'metapath' => File.join(@site_base, config['dst']['metapath'], "#{@project}.meta.json")
        }
        @presets = set_presets(config['presets'])
        @quality = config['quality']
        
        # prepare other instance vars
        @src['image_paths'] = []
        @images = []
        @size = 0 # filesize
        
        @processor_action = config['do']
        
        @dynamic = config['dynamic_fill']
        @pretty_json = config['pretty_json']
        @image_pages = config['image_pages']

        @processed = false
        
        # options to configure the javascript Gallery
        @opts = config['opts']

        # metadata for images
        @image_meta = {}
        @image_meta_orig = {}
      end

      # Create Image objects and checks if all presets are generated yet
      def read_origs
        raise "Directory with fullsize images doesn't exist: #{@src['basepath']}" unless Dir.exists?(@src['basepath'])
        # Read in sources
        @src['image_paths'] = Dir[File.join(@src['basepath'], EXT_PATTERN)]
        # normalize filenames
        normalize_basenames!
        @src['image_paths'].each_with_index do |src_path, idx|
          @images << Jekyll::GalleryGenerator::Image.new(self, src_path, 'index' => idx)
        end
      end

      # Returns true, when the filenames in the json_data Hash are equal to the 
      # origs read in with Gallery#read_origs and if all presets are generated
      def check_images(json_data)
        # compare number of files and filenames
        @images.size == json_data['gallery']['images'].size &&
        # compare filenames (filenames in json which come with digest as a postfix)
        @images.map{|img| img.src['filename']} == json_data['gallery']['images'].map do |image_json|
          image_json['filename'].gsub("-#{image_json['digest']}", '')
        end &&
        @images.all?(&:presets_generated?)
      end

      # Fills the Image instance vars for a correct Image#to_json, without 
      # having to run Gallery#generate_presets
      def read_json(json_data)
        @title = json_data['gallery']['title']
        set_presets(json_data['gallery']['presets'])
        json_data['gallery']['images'].each_with_index do |json_img, idx|
          # initiate a new Image object, if not already done
          img = @images[json_img['index']] ||= Jekyll::GalleryGenerator::Image.new(self, '.not-known', 'index' => json_img['index'])
          # set data on the image
          img.read_json(json_img)
          # set metadata on the image
          @image_meta[img.digest] = img.set_meta(@image_meta_orig[img.digest])
        end
      end

      # Generate resized images
      def generate_presets(force)
        # Initialize Progressbar (# images * presets + 1)
        progressbar = ProgressBar.create(:format => '%a |%b>>%i| %p%% %t', 
          :total => @images.size)
        @images.each do |img|
          # generate presets for the image
          img.generate_presets(force)
          # set metadata on the image
          @image_meta[img.digest] = img.set_meta(@image_meta_orig[img.digest])
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
          'meta'          => @meta,
          'project'       => @project,
          'postPath'      => @post_path,
          'postBasepath'  => @post_basepath,
          'postBaseurl'   => @post_baseurl,
          'presets'       => @presets,
          'imageCount'    => @images.size,
          'dynamic'       => @dynamic,
          'imagePages'   => @image_pages,
          'opts'          => @opts,
          'images'        => @images
        }
      end

      def processed!
        @processed = true
      end

      def processed?
        @processed
      end

      def remote?
        @dst['baseurl'].start_with?('http://', 'https://')
      end
      
      def size
        if @size == 0
          @presets.each do |p_key, preset|
            dirname = File.join(@dst['basepath'], p_key)
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
      def set_presets(presets)
        @presets = presets
        @presets.each do |p_key, preset|
          preset['baseurl'] = File.join(@dst['baseurl'], p_key)
        end
      end

      # Renames src Files if they have spaces in the Filename or if its
      # starts with an underscore, so that jekyll won't copy them.
      #
      # To exclude the generated files from uploading prefix the dest['base_dir']
      # with an underscore.
      def normalize_basenames!
        @src['image_paths'].map! do |path|
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
