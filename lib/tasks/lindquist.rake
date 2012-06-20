require "active-fedora"
require "nokogiri"
require "lindquist"
include Lindquist::DcHelpers
LDPD_COLLECTIONS_ID = 'http://libraries.columbia.edu/projects/aggregation'
LINDQUIST_COLLECTION_ID = 'burke_lindq'
def get_mods_nodes()
  file = File.new('fixtures/lindquist-mods.xml')
  mods_collection = Nokogiri::XML.parse(file)
  ns = {'mods' => 'http://www.loc.gov/mods/v3'}
  return mods_collection.xpath('/mods:modsCollection/mods:mods', ns)
end

def get_ldpd_content_pid
  Lindquist::Object.find(:identifier=>LDPD_COLLECTIONS_ID)[0]
end

def get_lindquist_pid
  Lindquist::Object.find(:identifier=>LINDQUIST_COLLECTION_ID)[0]
end

namespace :burke do
  task :pid do
    ActiveFedora::Base.fedora_connection[0] ||= ActiveFedora::RubydoraConnection.new(ActiveFedora.config.credentials)
    rubydora = ActiveFedora::Base.fedora_connection[0].connection
    puts rubydora.next_pid(:namespace=>'ldpd')
  end
  namespace :lindquist do
    desc "load a file of mods records"
    task :debug => :environment do
      puts "LDPD COLLECTIONS: #{get_ldpd_content_pid}"
      puts "LINDQUIST: #{get_lindquist_pid}"
      BagAggregator.find('ldpd:130506').delete
    end
    task :reset => :environment do
      pid = ENV['PID']
      dc_url = "https://sayers.cul.columbia.edu:8443/fedora/objects/#{pid}/datastreams/DC/content?asOfDateTime=2012-05-31T15:45:32.000Z"
      rels_ext_url = "https://sayers.cul.columbia.edu:8443/fedora/objects/#{pid}/datastreams/RELS-EXT/content?asOfDateTime=2012-05-31T15:45:32.000Z"
      obj = BagAggregator.find(pid)
      obj.dc.dsLocation = dc_url
      obj.rels_ext.dsLocation = rels_ext_url
      obj.save
    end
    task :ensure_collection => :environment do
      ldpd_coll = get_ldpd_content_pid
      if ldpd_coll.nil?
        raise "Could not find any object with dc:identifier=#{LDPD_COLLECTIONS_ID}"
      end
      ldpd_coll = BagAggregator.find(ldpd_coll)
      collection_pid = get_lindquist_pid
      if collection_pid.nil?
        collection = BagAggregator.new(:namespace=>'ldpd')
        collection.label = 'G.E.E. Lindquist Native American Collection'
        collection.save
        set_dc_identifier(collection,LINDQUIST_COLLECTION_ID)
        set_dc_title(collection,'G.E.E. Lindquist Native American Collection')
        set_dc_type(collection,'Collection')
        collection.save
        collection_pid = collection.pid
        ldpd_coll.add_member(collection)
      end
      puts "Lindquist objects collected under #{collection_pid}"
    end
    task :load => :ensure_collection do
      mods_list = get_mods_nodes
      images = File.new('fixtures/lindquist-images.txt')
      counter = 0
      limit = -1
      mods_list.each { |mods_node|
        counter += 1
        if limit == -1 or counter < limit
          images.seek(0)
          lo = Lindquist::Object.new(mods_node, images)
          begin
            lo.find_or_create_fedora_object(:create_content=>true,:create_resource=>true)
          rescue Exception => e
            puts "Error creating objects for #{lo.id}: #{e.to_s}"
            puts e.backtrace
          end
        end
      }
      images.close
    end
  end
end
