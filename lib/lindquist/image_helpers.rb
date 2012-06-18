require 'uri'
require 'open-uri'
require 'tempfile'
module Lindquist
  module ImageHelpers
    def setImageProperties(obj)
      ds = obj.datastreams['CONTENT']
      image_prop_nodes = []
      if ds.controlGroup == 'E'
        # get blob
        uri = URI.parse(ds.dsLocation)
        open(uri) { |blob|
          image_prop_nodes = Cul::Image::Properties.identify(blob).nodeset
        }
      else
        blob = Tempfile.new("blob")
        blob.write(ds.content)
        blob.close
        blob.open
        image_prop_nodes = Cul::Image::Properties.identify(blob).nodeset
        blob.close unless blob.closed?
      end
      image_prop_nodes.each { |node|
        if node["resource"]
          is_literal = false
          object = RDF::URI.new(node["resource"])
        else
          is_literal = true
          object = RDF::Literal(node.text)
        end
        predicate = RDF::URI("#{node.namespace.href}#{node.name}")
        obj.relationships(predicate).dup.each { |stmt|
          obj.relationships.delete(stmt)
        }
        obj.add_relationship(predicate,object, is_literal)
        obj.relationships_are_dirty=true
      }
    end
  end
end