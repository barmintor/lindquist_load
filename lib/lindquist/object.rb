module Lindquist
  class Object
    include DcHelpers
    include ModsHelpers
    include ImageHelpers
    DATA_PATH = '/fstore/archive/ldpd/preservation/lindquist/data/'
    NOKO_NS = {'mods' => 'http://www.loc.gov/mods/v3'}
    # mods_node : Nokogiri node for a mods container element
    # path_list : File object listing image file paths
    def initialize(mods_node, path_list)
      @mods = mods_node
      @path_list = path_list
    end
    
    def id
      @id ||= begin
        _id = @mods.xpath('./mods:identifier[@type=\'local\']', NOKO_NS)
        _id.text
      end
    end
    
    def title
      @title ||= begin
        _title = @mods.xpath('./mods:titleInfo/mods:title', NOKO_NS)
        _title.text
      end
    end
    
    def box
      @box ||= begin
        parts = id.split('_')
        @item = parts[3]
        parts[2]
      end
    end
    
    def item
      @item ||= begin
        parts = id.split('_')
        @box = parts[2]
        parts[3]
      end
    end
    
    def file_pattern
      @pattern ||= Regexp.compile("#{DATA_PATH}Lindquist_box_#{box}/#{id}[rv]\.tif")
    end
    
    def resource_paths
      @rpaths ||= begin
        _rpaths = @path_list.find_all {|line| line =~ file_pattern}
        _rpaths.each {|path| path.rstrip!}
        _rpaths
      end
    end
    
    def find_or_create_fedora_object(opts={:create_content=>true,:create_resource=>true})
      unless self.id and self.id.length > 0
        raise 'Cannot create objects without a mods:id'
      end
      collection_pid = Object.find(:identifier=>'burke_lindq')[0]
      collection_obj = nil
      if collection_pid.nil?
        raise 'Where is the Lindquist BagAggregator? Not found in ' + ActiveFedora.config.credentials[:url]
      else
        collection_obj = BagAggregator.find(collection_pid)
      end
      # - find obect in fedora for which the dc:identifier == id
      ca_pid = Object.find(:identifier => self.id)[0]
      if ca_pid.nil?
        unless opts[:create_content] == false
          ca_obj = ContentAggregator.new(:namespace=>'ldpd')
          ## - generate DC metadata from mods 
          set_dc_identifier(ca_obj,self.id)
          set_dc_title(ca_obj,self.title)
          ca_obj.label= self.title
          ## - create descMetadata datastream if necessary, and assign its content = @mods.to_xml
          @mods.default_namespace = 'http://www.loc.gov/mods/v3'
          ca_obj.datastreams['descMetadata'].content = @mods.to_xml
          ca_obj.dc.dirty = true
          add_default_permissions(ca_obj)
          ca_obj.save
          ca_pid = ca_obj.pid
          collection_obj.add_member(ca_obj)
          puts "Created a ContentAggregator pid=#{ca_pid} dc:identifier=#{self.id}"
        else
          puts "Would have created a ContentAggregator dc:identifier=#{self.id}"
        end
      else 
        ca_obj = ContentAggregator.find(ca_pid)
        Object.ensure_dc_field(ca_obj, :identifier, self.id)
        puts "Found a ContentAggregator pid=#{ca_pid} dc:identifier=#{self.id}"
        old_mods = ca_obj.datastreams['descMetadata'].content
        @mods.default_namespace = 'http://www.loc.gov/mods/v3'
        unless old_mods == @mods.to_xml
          ca_obj.datastreams['descMetadata'].content= @mods.to_xml
          ca_obj.save
        else
          # ca_obj.send :update_index
        end
      end
      ## - find all the related resource paths
      resource_paths.each { |path|
       sia_obj = find_or_create_image_aggregator(path, opts)
       unless sia_obj.nil? or sia_obj.containers.include? ca_obj.internal_uri
         ca_obj.add_member(sia_obj)
       end
      }
      
    end
    
    def find_or_create_image_aggregator(resource_path, opts={:create_resource=>true})
      side_label = nil
      if resource_path =~ /([rv])\.tif/
        side_label = ($1 == 'v') ? "Verso" : "Recto"
      else
        raise "This image path was malformed: #{resource_path} ( expected to match /([rv]).tif/ )"
      end
      r_pid = Object.find(:source => resource_path)[0]
      if r_pid.nil?
        unless opts[:create_resource] == false
          r_obj = GenericResource.new(:namespace=>'ldpd')
          ### - assign DC metadata values:
          #### - dc:source = filepath
          #### - dc:title = filepath
          set_dc_identifier(r_obj,resource_path)
          set_dc_source(r_obj,resource_path)
          r_title = "#{self.id} #{side_label} TIFF Image"
          r_obj.label = r_title
          set_dc_title(r_obj,r_title)
          set_dc_format(r_obj,'image/tiff')
          set_dc_type('Image')
          set_dc_coverage(side_label) if side_label
          r_obj.dc.dirty = true
          add_default_permissions(r_obj)
          ds_opts = {:controlGroup => 'E', :mimeType=>'image/tiff',:dsLocation => 'file:' + resource_path,:label=>resource_path}
          ds = r_obj.create_datastream(ActiveFedora::Datastream,'content', ds_opts)
          r_obj.add_datastream(ds)
          r_obj.save
          setImageProperties(r_obj)
          r_obj.save
          puts "Created a GenericResource pid=#{r_pid} dc:source=#{resource_path}"
        else
          puts "Would have created a GenericResource dc:source=#{resource_path}"
        end
      else
        r_obj = GenericResource.find(r_pid)
        Object.ensure_dc_field(r_obj, :source, resource_path)
        puts "Found a GenericResource pid=#{r_pid} dc:source=#{resource_path}"
      end
      # - each of these paths represents an ImageAggregator as well as a (File) Resource
      unless r_obj.nil?
        unless r_obj.datastreams['content']
          ds_opts = {:controlGroup => 'E', :mimeType=>'image/tiff',:dsLocation => 'file:' + resource_path,:label=>resource_path}
          ds = r_obj.create_datastream(ActiveFedora::Datastream,'content', ds_opts)
          r_obj.add_datastream(ds)
          r_obj.save
        end
        setImageProperties(r_obj)
        image_id = self.id + "#{side_label.downcase}"
        set_dc_identifier(r_obj,image_id)
        r_obj.save
        # - for each tiff resource there should be a unique StaticImageAggregator
        r_obj.containers.each do |sia_obj|
          # - create a new SIA, with title = CA title + " recto" or " verso" as appropriate
          if ActiveFedora::ContentModel.known_models_for( sia_obj ).include? StaticImageAggregator
            r_obj.remove_relationship_by_name("containers", sia_obj)
          end
        end
        return r_obj
      end
      return nil
    end
    
    def self.swap_key(map, k1, k2)
      if map.has_key? k1
        v1 = map[k1]
        if map.has_key? k2
          map[k1] = map[k2]
          map[k2] = v1
        else
          map.delete k1
          map[k2] = v1
        end
      end
    end
    
    def self.find(args, opts={})
      parms = args.dup
      if parms.is_a? String
        parms = {:pid => parms}
      else
        swap_key(parms, :create_date, :cDate)
        swap_key(parms, :modified_date, :mDate)
        swap_key(parms, :owner_id, :ownerId)
        swap_key(parms, :id, :pid)
      end
      query = ""
      parms.each { |key, val| 
        query.concat "#{key.to_s}~#{val.to_s} "
      }
      query.strip!
      results = ""
      if ActiveFedora.config.sharded?
        (0...ActiveFedora.config.credentials.length).each {|ix|
          ActiveFedora::Base.fedora_connection[ix] ||= ActiveFedora::RubydoraConnection.new(ActiveFedora.config.credentials[ix])
          rubydora = ActiveFedora::Base.fedora_connection[ix].connection
          results.concat rubydora.find_objects(:query=>query,:pid=>'true')
        }
      else
        ActiveFedora::Base.fedora_connection[0] ||= ActiveFedora::RubydoraConnection.new(ActiveFedora.config.credentials)
        rubydora = ActiveFedora::Base.fedora_connection[0].connection
        results = rubydora.find_objects(:query=>query,:pid=>'true')
      end
      results = Nokogiri::XML.parse(results)
      results = results.xpath('/f:result/f:resultList/f:objectFields/f:pid',{'f'=>"http://www.fedora.info/definitions/1/0/types/"})
      results.collect { |result| result.text }
    end

    def self.ensure_dc_field(obj, key, value)
      values = obj.dc.term_values(key)
      unless values.include? value
        raise "#{obj.pid} DC does not contain #{key.to_s} value of #{value} : #{obj.dc}"
      end
    end

    private
    def add_default_permissions(obj)
      ds = obj.datastreams['rightsMetadata']
      ds.ensure_xml_loaded
      ds.save
      ds.update_values([{:discover_access=>"0"},:group]=>"staff")
      ds.update_values([{:read_access=>"0"},:group]=>"staff")
      ds.update_values([{:edit_access=>"0"},:group]=>"archivist")
      obj.save
    end    
  end
end
