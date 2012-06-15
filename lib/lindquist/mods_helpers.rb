module Lindquist
  module ModsHelpers
    def set_mods_identifier(obj, val)
      obj.datastreams['descMetadata'].update_indexed_attributes([:identifier=>0]=>val)
      obj.datastreams['descMetadata'].dirty = true
    end
    def set_mods_title(obj, val)
      obj.datastreams['descMetadata'].update_indexed_attributes([:title=>0]=>val)
      obj.datastreams['descMetadata'].dirty = true
    end
  end
end