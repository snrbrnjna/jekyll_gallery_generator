module Jekyll
  module GalleryGenerator
    class GalleryGenerator < Generator
        
      include Processors

      priority :normal
      
      DEFAULTS = {
        'src' => {
          'basepath' => '_galleries/fullsizes'
        }, 
        'dst' => {
          'basepath' => '_galleries/generated',
          'baseurl'  => '/img/galleries',
          'metapath' => '_galleries/metadata'
        }, 
        'presets' => {
          'thumb' =>        { 'width' =>  450 },
          'large_phones' => { 'width' =>  650 },
          'large_pads' =>   { 'width' => 1024 }, 
          'large' =>        { 'width' => 1400 } 
        },
        'do' => 'check_images', # check_images|generate_data|generate_images|nothing
        'quality' => 100,
        'opts' => {     # opts for gallery frontend
          'min_col_width' => {
            'desktop' =>  320,
            'pad' =>      320,
            'phone' =>    300
          },
          'gutter_width' =>   3,
          'chunk_size' =>     8,
          'first_chunk' =>   15
        },
        'pretty_json' => false,
        'dynamic_fill' => true,
        'image_pages' => false
      }

      def generate site
        # set site wide gallery defaults
        @defaults = merge_defaults DEFAULTS, site.config['gallery']

        # Hash of all processed Gallery objects
        @galleries = {}; 

        # Save some stats for User Feedback
        @gallery_stats = []; @galleries_size = 0

        # filter gallery posts
        payload = site.site_payload
        gallery_posts = payload['site']['posts'].select do |post| 
          post.data['layout'] == 'gallery'
        end

        if gallery_posts.any?
          if site.config['gallery']
      
            # logging
            puts; puts "#### #{gallery_posts.size} Gallery-Posts"
                  
            gallery_posts.select(&:published?).each do |gp|
                              
              # Initialize Gallery object                   
              gallery = init_gallery(site, gp)

              # Logging
              puts "Processing Gallery '#{gallery.project}' ..."

              # Check if gallery was processed yet (Set plugin)
              gallery.processed! if @galleries.keys.include?(gallery.project)

              # Read in Image Metadata
              gallery.image_meta_orig = parse_meta(gallery)

              # Get Processor Strategy from gallery's config
              strategy = map_processor(gallery)

              # Call the strategy
              status = strategy.call(self, gallery)

              # Generate Redirect Posts for Gallery images
              gallery.images.each do |image|
                begin
                  image.generate_redirect_page(site, gallery)
                rescue => error
                  warn 'ERROR - could not generate redirect pages for images: '.red + error.message
                  break
                end
              end if gallery.image_pages

              # Update Image Metadata File
              write_meta(gallery)

              # Saves Gallery JSON and copies file to Jekyll site destination
              write_json(gallery)
              copy_json(site, gp, gallery)
          
              # Sync generated images
              unless gallery.processed? || gallery.remote?
                sync_presets(site, gallery)
                prevent_jekyll_from_removing_synced_presets(site, gallery)
              end # end copy images

              # Save log output for current gallery
              log_gallery(gallery, status)
          
              # Save gallery id for not generating a gallery twice
              @galleries[gallery.project] = gallery

              # Mark Gallery as processed
              gallery.processed!
          
            end # end each published gallery_posts

            # logging summary stats
            log_summary()
          else
            puts "There are Gallery-Posts, but no Gallery configuration, hence the galleries are not processed".red
          end # end site.config
        end # end gallery_posts.any?
      end # end generate



      # sets site wide gallery defaults
      def merge_defaults defaults, gallery_opts
        # Build Options for Gallery constructor
        if gallery_opts
          config = {}
          config['src'] = defaults['src'].merge(gallery_opts['src'] || {})
          config['dst'] = defaults['dst'].merge(gallery_opts['dst'] || {})
          config['presets'] = defaults['presets'].merge(gallery_opts['presets'] || {})
          config['quality'] = gallery_opts['quality'] || defaults['quality']
          config['dynamic_fill'] = gallery_opts.has_key?('dynamic_fill') ? 
            gallery_opts['dynamic_fill'] : 
            defaults['dynamic_fill']
          config['pretty_json'] = gallery_opts.has_key?('pretty_json') ? 
            gallery_opts['pretty_json'] : 
            defaults['pretty_json']
          config['image_pages'] = gallery_opts.has_key?('image_pages') ?
            gallery_opts['image_pages'] :
            defaults['image_pages']
          config['do'] = gallery_opts['do'] || defaults['do']
          config['opts'] ||= {}
          if (gallery_opts['opts'])
            if gallery_opts['opts']['min_col_width'].is_a?(Integer)
              config['opts']['min_col_width'] = gallery_opts['opts']['min_col_width']
            else
              config['opts']['min_col_width'] = defaults['opts']['min_col_width'].merge(
                gallery_opts['opts']['min_col_width'] || {}
              )
            end
            config['opts']['gutter_width'] = gallery_opts['opts']['gutter_width'] || 
              defaults['opts']['gutter_width']
            config['opts']['chunk_size'] = gallery_opts['opts']['chunk_size'] || 
              defaults['opts']['chunk_size']
            config['opts']['first_chunk'] = gallery_opts['opts']['first_chunk'] || 
              defaults['opts']['first_chunk']
          else
            config['opts'] = defaults['opts']
          end
          return config
        else
          return {}.merge(defaults)
        end
      end

      # Initialize Gallery Object from gallery_post
      def init_gallery site, gallery_post
        # Front Matter YAML Data
        data = gallery_post.data
    
        # Create Gallery instance
        begin
          # Build Options for Gallery constructor
          config = merge_defaults @defaults, data['gallery_config']

          # project (aka id of gallery post comes from it's slug)
          config['project'] = (data['gallery_config'] && data['gallery_config']['project']) || 
            gallery_post.slug

          gallery = Jekyll::GalleryGenerator::Gallery.new(
            site, data['title'], gallery_post, config
          )
        rescue ArgumentError => error
          warn 'ERROR: '.red + error.message
          return
        end
    
        # Add Gallery to post data (all Gallery#to_liquid data)
        return gallery_post.data['gallery'] = gallery 
      end

      # Asks the gallery for the processor action it has defined (with config 
      # param ``do``) and maps it with a Processor Proc object.
      def map_processor gallery
        case gallery.processor_action
        when 'nothing' then
          NOTHING
        when 'check_images' then
          CHECK_IMAGES
        when 'generate_data' then
          GENERATE_DATA
        when 'generate_images' then
          GENERATE_IMAGES
        else
          raise Exception.new("Invalid action defined with 'do' commando '#{gallery.processor_action}'!")
        end
      end

      # Tries to read in the json data of the given gallery and returns it's data
      # Hash, or nil
      def parse_json gallery
        json_path = gallery.dst['jsonpath']
        begin
          io = IO.read(json_path)
          JSON.parse(io)
        rescue
          nil
        end
      end

      # Generates a JSON File for the given gallery.
      def write_json gallery
        filepath = gallery.dst['jsonpath']
        
        # Create Dst Directory if not existent yet
        filedir = File.dirname(filepath)
        FileUtils.mkdir_p(filedir) unless File.exists?(filedir)
        
        # Write the contents of gallery json.
        filename = File.basename(filepath)
        File.open(filepath, 'w') do |f|
          if gallery.pretty_json
            f.write(JSON.pretty_generate(
              { 'gallery' => gallery }
            ))
          else
            f.write(JSON.generate(
              { 'gallery' => gallery }
            ))
          end
          f.close
        end
      end
      
      # Copies json file to Jekyll site destination and creates a StaticFile for
      # not beeing removed in Jekyll's cleanup call.
      def copy_json site, gallery_post, gallery
        src_filepath = gallery.dst['jsonpath']
        filename = File.basename src_filepath

        # Get destination directory
        dst_dir = File.join(site.dest, gallery.post_basepath)

        # Mkdir if destination dir doesn't exist yet
        FileUtils.mkdir_p(dst_dir) unless File.exists?(dst_dir)
        
        # Copy json file
        FileUtils.cp(src_filepath, File.join(dst_dir, filename))

        # Prevent Jekyll from erasing our generated files
        site.static_files << StaticGalleryFile.new(
          site, site.source, gallery.post_basepath, filename
        )
      end

      # Read in Metadata File for given gallery
      def parse_meta gallery
        metapath = gallery.dst['metapath']
        begin
          io = IO.read(metapath)
          JSON.parse(io)
        rescue
          {}
        end
      end

      # Write Image Metadata of given gallery to its metafile.
      def write_meta gallery
        filepath = gallery.dst['metapath']

        # Create Dst Directory if not existent yet
        filedir = File.dirname(filepath)
        FileUtils.mkdir_p(filedir) unless File.exists?(filedir)

        # Write JSON File
        File.open(filepath.gsub('.yaml', '.json'), 'w') do |io|
          io.write(JSON.pretty_generate(gallery.image_meta))
          io.close
        end
      end
      
      # Sync Presets of Gallery to Jekyll site destination
      #
      # We copy by ourself, because the directory structure doesn't
      # fit into the schema with which Mr. Jekyll is used to work
      # (details in Jekyll::StaticFile)
      def sync_presets site, gallery
        dst_dir = File.join(site.dest, gallery.dst['baseurl'])
        FileUtils.mkdir_p(dst_dir) unless File.exists?(dst_dir)
        # Rsync Image Files to dst_dir
        rsync_options = [
          '--recursive', 
          '--delete', 
          '--times',
          '--delete-excluded', 
          '--exclude=*.json',
          '--exclude=.DS_Store',
          '--human-readable' # for debugging, combine with --verbose --progress'
        ]
        rsync_call = "rsync #{gallery.dst['basepath']}/ #{dst_dir}/ #{rsync_options.join(' ')}"
        unless system(rsync_call)
          warn 'ERROR: '.red + "Error when copying images! Call '#{rsync_call}' returned with exit code #{$?.exitstatus}"
        end
      end

      # Prevent the gallery directories and image files from beeing removed 
      # by Jekylls cleanup method
      def prevent_jekyll_from_removing_synced_presets site, gallery
        # Workaround.... for issue: https://github.com/mojombo/jekyll/issues/1297
        # We Have to create a virtual static file in every subdirectory of 
        # gallery dst baseurl, else these directories are washed away by
        # Jekylls cleanup method...
        path_comps = gallery.dst['baseurl'].split(File::SEPARATOR)
        path_comps.each_with_index do |path_comp, idx|
          site.static_files << StaticGalleryFile.new(
            site, '', File.join(path_comps[0, idx+1]), 'keepme'
          )
        end

        # Prevent the image files from beeing removed again by 
        # Jekylls cleanup method
        site.keep_files << gallery.dst['baseurl'] unless site.keep_files.include?(gallery.dst['baseurl'])
        gallery.images.each do |img|
          img.presets.each_key do |preset_key|
            site.static_files << StaticGalleryFile.new(
              site, '', img.dst[preset_key]['baseurl'], img.dst['filename']
            )
          end
        end
      end

      def log_gallery gallery, status
        # Filesize stats
        @galleries_size += gallery.size
        unless (gallery.processed?)
          @gallery_stats << "#{gallery.title}".send(status == :nothing ? 'cyan' : 'green') +
            " - #{gallery.images.size} Images, #{gallery.size.to_human}" +
            " (Quality: #{gallery.quality}%)"
          preset_stats = gallery.presets.map do |p_key, preset|
            size = preset['size']
            "  #{p_key}:\t\t#{size.to_human} (~ #{(size/gallery.images.count).floor.to_human})"
          end
          @gallery_stats << preset_stats
        end
      end

      def log_summary
        puts; puts @gallery_stats
        if @galleries_size < 7516192768
          puts "Total of #{@galleries_size.to_human}".green
        else 
          puts "Total of #{@galleries_size.to_human} CAUTION: your quota is going to be exhausted soon!".red
        end
      end

    end


    # Sub-class Jekyll::StaticFile to allow recovery from unimportant exception
    # when writing the sitemap file.
    class StaticGalleryFile < Jekyll::StaticFile
      def write(dest)
        super(dest) rescue [ArgumentError, TypeError]
        true
      end
    end

  end
end
