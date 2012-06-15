require 'active_support'

module Lindquist
  extend ActiveSupport::Autoload
  
  eager_autoload do 
    autoload :DcHelpers
    autoload :ImageHelpers
    autoload :ModsHelpers
    autoload :Object
  end
end