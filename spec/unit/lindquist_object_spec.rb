require 'spec_helper'
describe Lindquist::Object do
  before :all do
    @images = File.open('./fixtures/lindquist-images.txt','r')
    @mods = Nokogiri::XML.parse(File.open('./spec/fixtures/test-mods.xml')).xpath('/mods:modsCollection/mods:mods',{'mods'=>"http://www.loc.gov/mods/v3"})[0]
    @test_object = Lindquist::Object.new(@mods, @images)
  end
  
  it "should correctly parse the item id" do
    @test_object.id.should == 'burke_lindq_035_0024'
  end
  
  it "should correctly parse the box number" do
    @test_object.box.should == '035'
  end
  
  it "should find the title" do
    @test_object.title.should == "Indian Nurses in Training at Ganado Hospital, Arizona"
  end
  
  it "should find the correct images by matching a regex pattern" do
    @test_object.resource_paths.should == ['/fstore/archive/ldpd/preservation/lindquist/data/Lindquist_box_035/burke_lindq_035_0024r.tif',
                                           '/fstore/archive/ldpd/preservation/lindquist/data/Lindquist_box_035/burke_lindq_035_0024v.tif']
  end
  
  describe ".swap_key" do
    it "should replace an existing key with passed non-existent key" do
      test_map = {:foo=>"bar"}
      Lindquist::Object.swap_key(test_map,:foo,:FOO)
      test_map.should == {:FOO=>"bar"}
      Lindquist::Object.swap_key(test_map,:foo,:FOO)
      test_map.should == {:FOO=>"bar"}
    end
    
    it "should swap the values for two existing keys" do
      test_map = {:foo=>"bar",:FOO=>"BAR"}
      Lindquist::Object.swap_key(test_map,:foo,:FOO)
      test_map.should == {:foo=>"BAR",:FOO=>"bar"}
      Lindquist::Object.swap_key(test_map,:foo,:FOO)
      test_map.should == {:foo=>"bar",:FOO=>"BAR"}
    end
    
    it "should do nothing if neither key exists" do
      test_map = {:foo=>"bar",:FOO=>"BAR"}
      Lindquist::Object.swap_key(test_map,:bar,:BAR)
      test_map.should == {:foo=>"bar",:FOO=>"BAR"}
    end
  end
end
