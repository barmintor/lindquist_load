module Lindquist
  module DcHelpers
    def set_dc_identifier(obj, val)
      obj.dc.update_indexed_attributes([:identifier=>0]=>val)
      obj.dc.dirty = true
    end
    def set_dc_source(obj, val)
      obj.dc.update_indexed_attributes([:source=>0]=>val)
      obj.dc.dirty = true
    end
    def set_dc_title(obj, val)
      obj.dc.update_indexed_attributes([:title=>0]=>val)
      obj.dc.dirty = true
    end
    def set_dc_type(obj, val)
      obj.dc.update_indexed_attributes([:dc_type=>0]=>val)
      obj.dc.dirty = true
    end
    def set_dc_format(obj, val)
      obj.dc.update_indexed_attributes([:format=>0]=>val)
      obj.dc.dirty = true
    end
  end
end