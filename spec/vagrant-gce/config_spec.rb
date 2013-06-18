# Copyright 2013 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
require "vagrant-gce/config"

describe VagrantPlugins::GCE::Config do
  let(:instance) { described_class.new }

  # Ensure tests are not affected by GCE credential environment variables
  before :each do
    ENV.stub(:[] => nil)
  end

  describe "defaults" do
    subject do
      instance.tap do |o|
        o.finalize!
      end
    end

    its("image")             { should == "debian-7" }
    its("region")            { should == "us-central1" }
    its("zone")              { should == "us-central1-a" }
    its("machine_type")      { should == "n1-standard-1" }
    its("instance_ready_timeout") { should == 30 }
    its("tags")              { should == {} }
    its("metadata")          { should == {} }
  end

  describe "overriding defaults" do
    # I typically don't meta-program in tests, but this is a very
    # simple boilerplate test, so I cut corners here. It just sets
    # each of these attributes to "foo" in isolation, and reads the value
    # and asserts the proper result comes back out.
    [:image, :zone, :instance_ready_timeout, :machine_type, :region,
      :tags, :metadata].each do |attribute|

      it "should not default #{attribute} if overridden" do
        instance.send("#{attribute}=".to_sym, "foo")
        instance.finalize!
        instance.send(attribute).should == "foo"
      end
    end
  end

  describe "getting credentials from environment" do
    context "without GCE credential environment variables" do
      subject do
        instance.tap do |o|
          o.finalize!
        end
      end

      its("google_client_email") { should be_nil }
      its("google_key_location") { should be_nil }
    end

    context "with GCE credential environment variables" do
      before :each do
        ENV.stub(:[]).with("GOOGLE_CLIENT_EMAIL").and_return("client_id_email")
        ENV.stub(:[]).with("GOOGLE_KEY_LOCATION").and_return("/path/to/key")
      end

      subject do
        instance.tap do |o|
          o.finalize!
        end
      end

      its("google_client_email") { should == "client_id_email" }
      its("google_key_location") { should == "/path/to/key" }
    end
  end

  describe "region config" do
    let(:config_image)           { "foo" }
    let(:config_machine_type)    { "foo" }
    let(:config_region)          { "foo" }
    let(:config_zone)            { "foo" }

    def set_test_values(instance)
      instance.image             = config_image
      instance.machine_type      = config_machine_type
      instance.region            = config_region
      instance.zone              = config_zone
    end

    it "should raise an exception if not finalized" do
      expect { instance.get_region_config("us-central1") }.
        to raise_error
    end

    context "with no specific config set" do
      subject do
        # Set the values on the top-level object
        set_test_values(instance)

        # Finalize so we can get the region config
        instance.finalize!

        # Get a lower level region
        instance.get_region_config("us-central1")
      end

      its("image")             { should == config_image }
      its("machine_type")      { should == config_machine_type }
      its("region")            { should == config_region }
      its("zone")              { should == config_zone }
    end

    context "with a specific config set" do
      let(:region_name) { "hashi-region" }

      subject do
        # Set the values on a specific region
        instance.region_config region_name do |config|
          set_test_values(config)
        end

        # Finalize so we can get the region config
        instance.finalize!

        # Get the region
        instance.get_region_config(region_name)
      end

      its("image")             { should == config_image }
      its("machine_type")      { should == config_machine_type }
      its("region")            { should == region_name }
    end

    describe "inheritance of parent config" do
      let(:region_name) { "hashi-region" }

      subject do
        # Set the values on a specific region
        instance.region_config region_name do |config|
          config.image = "child"
        end

        # Set some top-level values
        instance.image = "parent"

        # Finalize and get the region
        instance.finalize!
        instance.get_region_config(region_name)
      end

      its("image")           { should == "child" }
    end

    describe "shortcut configuration" do
      subject do
        # Use the shortcut configuration to set some values
        instance.region_config "us-central1", :image => "child"
        instance.finalize!
        instance.get_region_config("us-central1")
      end

      its("image") { should == "child" }
    end

    describe "merging" do
      let(:first)  { described_class.new }
      let(:second) { described_class.new }

      it "should merge the tags" do
        first.tags["one"] = "one"
        second.tags["two"] = "two"

        third = first.merge(second)
        third.tags.should == {
          "one" => "one",
          "two" => "two"
        }
      end
    end
  end
end
