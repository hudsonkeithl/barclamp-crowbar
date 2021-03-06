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
 
class RoleInstanceModelTest < ActiveSupport::TestCase

  def setup
    @role = Role.find_or_create_by_name :name => "test"
    assert_not_nil @role
    @bc = Barclamp.create :name=>"instance"
    assert_not_nil @bc
    @bi = BarclampInstance.create :name=>"template", :barclamp_configuration_id => @bc.id, :barclamp_id => @bc.id
    assert_not_nil @bi
    @bc.template_id = @bi.id
    @bc.save
    @ri = RoleInstance.create :barclamp_instance_id => @bi.id, :role_id=>@role.id
    assert_not_nil @ri
  end
  
  test "Barclamp Template has RoleInstances" do
    assert_not_nil @bc
    bi = @bc.template
    assert_not_nil bi
    assert bi.role_instances.count>0, "we need to have at least 1 role"
    ri = bi.role_instances.first
    assert_equal "test", ri.role.name, "one of the roles is the one from setup"
  end

  test "Relation to BarclampInstance" do
    assert_equal "template", @ri.barclamp_instance.name
    assert_equal "template", @ri.instance.name
  end
  
  test "Relation to Role" do
    assert_not_nil @ri.role
    assert_equal "test", @ri.role.name
    assert_equal "test", @ri.name
  end

  test "Relation to AttribInstance" do
    return 
    # work in progress...
    a = Attrib.create :name=>"foo"
    assert_not_nil Attrib.find_by_name "foo"
    ai = @ri.add_attrib a, "map/this"
    @ri.set_attrib(a, "bar")
    assert_not_nil ai
    assert_equal "foo", ai.attrib.name
    assert_equal "bar", ai.value
    assert_equal "map/this", ai.description
    assert_equal "bar", @ri.get_attrib("foo").value
  end

  test "Deep clone works at surface layer" do
    r = Role.create :name => "clone" 
    assert_not_nil r
    ri = RoleInstance.create :role_id=>r.id, :barclamp_instance_id => @bi.id
    new_bi = BarclampInstance.create :name => "value", :barclamp_id => @bi.barclamp.id
    new_ri = ri.deep_clone new_bi
    assert_not_equal ri.id, new_ri.id, "different objects"
    assert_equal ri.role_id, new_ri.role_id, "should have the same role"
    assert_not_equal ri.barclamp_instance_id, new_ri.barclamp_instance_id, "should not have same instance"
  end

  test "Deep clone works at attrib layer" do
    r = Role.create :name => "deep_clone" 
    ri = RoleInstance.create :role_id=>r.id, :barclamp_instance_id => @bi.id
    ri.add_attrib 'foo', 'bar'
    ri.add_attrib 'open', 'stack'
    assert_equal 2, ri.values.count
    first = ri.values.first
    second = ri.values.second
    new_bi = BarclampInstance.create :name => "deep_value", :barclamp_id => @bi.barclamp.id
    new_ri = ri.deep_clone new_bi
    assert_not_nil new_ri
    assert_not_nil 2, new_ri.values.count
    assert_equal first.name, new_ri.values.first.name
    assert_equal first.value, new_ri.values.first.value
    assert_equal second.name, new_ri.values.second.name
    assert_equal second.value, new_ri.values.second.value
  end

end

