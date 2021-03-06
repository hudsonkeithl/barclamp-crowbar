# Copyright 2013, Dell 
# 
# Licensed under the Apache License, Version 2.0 (the "License"); 
# you may not use this file except in compliance with the License. 
# You may obtain a copy of the License at 
# 
#  http://www.apache.org/licenses/LICENSE-2.0 
# 
# Unless required by applicable law or agreed to in writing, software 
# distributed under the License is distributed on an "AS IS" BASIS, 
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
# See the License for the specific language governing permissions and 
# limitations under the License. 
# 
require 'test_helper'
 
class BarclampConfigModelTest < ActiveSupport::TestCase

  def setup
    @bc = Barclamp.create! :name=>'bc_config_test'
  end
  
  test "Unique per Barclamp Name" do
    b1 = Barclamp.create! :name=>"nodup1"
    b2 = Barclamp.create! :name=>"nodup2"
    assert_not_nil b1
    assert_not_nil b2
    bc1 = BarclampConfiguration.create :name=>"nodup", :barclamp_id=>b1.id
    assert_not_nil bc1
    bc2 = BarclampConfiguration.create :name=>"nodup", :barclamp_id=>b2.id
    assert_not_nil bc2
    assert_not_equal bc1.id, bc2.id
    
    e = assert_raise(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, SQLite3::ConstraintException) { BarclampConfiguration.create!(:name => "nodup", :barclamp_id=>b1.id) }
  end
  
  test "Check protections on illegal names" do
    assert_raise(ActiveRecord::RecordInvalid) { BarclampConfiguration.create!(:name => "1123", :barclamp_id=>@bc.id) }
    assert_raise(ActiveRecord::RecordInvalid) { BarclampConfiguration.create!(:name => "1foo", :barclamp_id=>@bc.id) }
    assert_raise(ActiveRecord::RecordInvalid) { BarclampConfiguration.create!(:name => "Ille!gal", :barclamp_id=>@bc.id) }
    assert_raise(ActiveRecord::RecordInvalid) { BarclampConfiguration.create!(:name => " nospaces", :barclamp_id=>@bc.id) }
    assert_raise(ActiveRecord::RecordInvalid) { BarclampConfiguration.create!(:name => "no spaces", :barclamp_id=>@bc.id) }
    assert_raise(ActiveRecord::RecordInvalid) { BarclampConfiguration.create!(:name => "nospacesatall ", :barclamp_id=>@bc.id) }
  end

  test "Active works" do
    config = BarclampConfiguration.create :name=>"active", :barclamp_id=>@bc.id
    assert_equal 0, config.barclamp_instances.count
    assert_equal 0, config.instances.count
    assert       !config.active?
    assert_nil   config.active_instance
    # add instance
    instance = BarclampInstance.create :name=>"active2", :barclamp_configuration_id=>config.id, :barclamp_id => @bc.id
    assert_equal 1, config.instances.count
    assert       !config.active?
    assert_nil   config.active_instance
    # now activate
    config.active_instance = instance
    assert_equal 1, config.instances.count
    assert       config.active?
    assert_equal instance, config.active_instance
  end
  
  test "status check missing" do
    config = BarclampConfiguration.create :name=>"status", :barclamp_id=>@bc.id
    instance = BarclampInstance.create :name=>"status2", :barclamp_configuration_id=>config.id, :barclamp_id => @bc.id
    c = BarclampConfiguration.find config.id
    assert_equal  'inactive', c.status
  end
  
  test "status check none" do
    config = BarclampConfiguration.create :name=>"status", :barclamp_id=>@bc.id
    instance = BarclampInstance.create :name=>"status2", :barclamp_configuration_id=>config.id, :status =>BarclampInstance::STATUS_NONE, :barclamp_id => @bc.id
    config.active_instance = instance
    config.save!
    c = BarclampConfiguration.find config.id
    assert_equal  'none', c.status
  end
  
  test "status check pending" do    
    config = BarclampConfiguration.create :name=>"status", :barclamp_id=>@bc.id
    instance = BarclampInstance.create :name=>"status2", :barclamp_configuration_id=>config.id, :status =>BarclampInstance::STATUS_QUEUED, :barclamp_id => @bc.id
    config.active_instance = instance
    config.save!
    c = BarclampConfiguration.find config.id
    assert_equal  'pending', c.status  
  end
  
  test "status check unready" do
    config = BarclampConfiguration.create :name=>"status", :barclamp_id=>@bc.id
    instance = BarclampInstance.create :name=>"status2", :barclamp_configuration_id=>config.id, :status =>BarclampInstance::STATUS_COMMITTING, :barclamp_id => @bc.id
    config.active_instance = instance
    config.save!
    c = BarclampConfiguration.find config.id
    assert_equal  'unready', c.status
  end
  
  test "status check failed" do
    config = BarclampConfiguration.create :name=>"status", :barclamp_id=>@bc.id
    instance = BarclampInstance.create :name=>"status2", :barclamp_configuration_id=>config.id, :status =>BarclampInstance::STATUS_FAILED, :barclamp_id => @bc.id
    config.active_instance = instance
    config.save!
    c = BarclampConfiguration.find config.id
    assert_equal  'failed', c.status
  end
  
  test "status check applied" do
    config = BarclampConfiguration.create :name=>"status", :barclamp_id=>@bc.id
    instance = BarclampInstance.create :name=>"status2", :barclamp_configuration_id=>config.id, :status => BarclampInstance::STATUS_APPLIED, :barclamp_id => @bc.id
    config.active_instance = instance
    config.save!
    c = BarclampConfiguration.find config.id
    assert_equal  'ready', c.status
  end
  
  test "status check hold" do
    config = BarclampConfiguration.create :name=>"status", :barclamp_id=>@bc.id
    instance = BarclampInstance.create :name=>"status2", :barclamp_configuration_id=>config.id, :status => -1, :barclamp_id => @bc.id
    config.active_instance = instance
    config.save!
    c = BarclampConfiguration.find config.id
    assert_equal  'hold', c.status    
  end
  
  test "create proposal without name is default" do
    test = Barclamp.import 'test'
    assert_equal 0, test.configs.count
    assert_not_nil test.template
    config = test.create_proposal
    assert_not_nil config
    assert_equal 1, test.configs(true).count
    assert_equal config.id, test.configs.first.id
    assert_equal I18n.t('default'), config.name
    assert_equal test.id, config.barclamp_id
  end
  
  test "Can create config from barclamp" do
    test = Barclamp.import 'test'
    assert !test.allow_multiple_configs, "need this to be 1 for this test"
    assert_equal 0, test.configs.count
    assert_not_nil test.template
    config = test.create_proposal 'foo'
    assert_not_nil config
    assert_equal 1, test.configs(true).count
    assert_equal config.id, test.configs.first.id
    assert_equal 'foo', config.name
    assert_equal test.id, config.barclamp_id
  end
  
  test "Allow multiple proposals works" do
    test = Barclamp.import 'test'
    assert !test.allow_multiple_configs, "need this to be 1 for this test"
    assert_equal 0, test.configs.count
    assert_not_nil test.template
    config = test.create_proposal 'foo'
    assert_not_nil config
    # this will fail
    c2 = test.create_proposal 'bar'
    assert_nil c2
    assert_equal 'foo', test.configs(true).first.name
    assert_equal 1, test.configs(true).count
    # now change the setting and try again
    test.allow_multiple_configs = true
    c3 = test.create_proposal 'bar'
    assert_not_nil c3
    assert_equal 'bar', c3.name
    assert_equal 2, test.configs(true).count
  end
  
  test "create proposal clones roles" do    
    test = Barclamp.import  'test'
    assert_not_nil test
    count = test.template.role_instances.count
    r = test.template.add_role "clone_me"
    assert_not_nil r
    # make sure this role is first in the list
    r.run_order = 1
    r.order = 1
    r.save
    assert_equal "clone_me", r.role.name
    assert_equal r.role.id, test.template.role_instances.second.role.id, "confirm that added role is second after private"
    # now make sure it shiows up in the cone
    config = test.create_proposal "cloned"
    assert_not_nil config
    assert_not_equal test.template_id, config.id
    assert_equal test.template.role_instances.count, config.proposed.role_instances.count
    assert_equal test.template.role_instances.second.role_id, config.proposed.role_instances.second.role_id
  end
end

