require 'spec_helper'

# skip system specs unless we can load linux_admin
skip_system = false
begin
  require 'linux_admin'
rescue LoadError
  skip_system = true
end

  describe BundlerExt do
    before(:each) do
      @gemfile = 'spec/fixtures/Gemfile.in'
    end
    after(:each) do
      ENV['BUNDLER_PKG_PREFIX'] = nil
      ENV['BEXT_ACTIVATE_VERSIONS'] = nil
      ENV['BEXT_PKG_PREFIX'] = nil
      ENV['BEXT_NOSTRICT'] = nil
      ENV['BEXT_GROUPS'] = nil
    end

    describe "#parse_from_gemfile" do
      describe "with no group passed in" do
        it "should return nothing to require" do
          libs = BundlerExt.parse_from_gemfile(@gemfile)
          libs.should be_an(Hash)
          libs.keys.should_not include('deltacloud-client')
          libs.keys.should_not include('vcr')
        end
      end
      describe "with :all passed in" do
        it "should return the list of system libraries in all groups to require" do
          libs = BundlerExt.parse_from_gemfile(@gemfile, :all)
          libs.should be_an(Hash)
          libs.keys.should include('deltacloud-client')
          libs['deltacloud-client'][:files].should == ['deltacloud']
          libs.keys.should include('vcr')
        end
      end
      describe "with group passed in" do
        it "should not return any deps that are not in the 'development' group" do
          libs = BundlerExt.parse_from_gemfile(@gemfile,'development')
          libs.should be_an(Hash)
          libs.keys.should_not include('deltacloud-client')
        end
        it "should return only deps that are in the :test group" do
          libs = BundlerExt.parse_from_gemfile(@gemfile, :test)
          libs.should be_an(Hash)
          libs.keys.should_not include('deltacloud-client')
          libs.keys.should include('vcr')
        end
        it "should return deps from both the :default and :test groups" do
          libs = BundlerExt.parse_from_gemfile(@gemfile, :default, :test)
          libs.should be_an(Hash)
          libs.keys.should include('deltacloud-client')
          libs.keys.should include('vcr')
        end
      end
      it "should only return deps for the current platform" do
        libs = BundlerExt.parse_from_gemfile(@gemfile)
        libs.should be_an(Hash)
        if RUBY_VERSION < "1.9"
          libs.keys.should_not include('cinch')
        else
          libs.keys.should_not include('fastercsv')
        end
      end
    end
    describe "#system_require" do
      it "strict mode should fail loading non existing gem" do
        expect { BundlerExt.system_require(@gemfile, :fail) }.to raise_error
      end

      it "non-strict mode should load the libraries in the gemfile" do
        ENV['BEXT_NOSTRICT'] = 'true'
        BundlerExt.system_require(@gemfile)
        defined?(Gem).should be_true
      end

      it "non-strict mode should load the libraries in the gemfile" do
        ENV['BUNDLER_EXT_NOSTRICT'] = 'true'
        BundlerExt.system_require(@gemfile)
        defined?(Gem).should be_true
      end

      it "non-strict mode should load the libraries in the gemfile" do
        ENV['BEXT_NOSTRICT'] = 'true'
        BundlerExt.system_require(@gemfile, :fail)
        defined?(Gem).should be_true
      end

      it "non-strict mode should load the libraries in the gemfile" do
        ENV['BUNDLER_EXT_NOSTRICT'] = 'true'
        BundlerExt.system_require(@gemfile, :fail)
        defined?(Gem).should be_true
      end
      it "non-strict mode should load the libraries using env var list" do
        ENV['BEXT_GROUPS'] = 'test development blah'
        ENV['BEXT_NOSTRICT'] = 'true'
        BundlerExt.system_require(@gemfile)
        defined?(Gem::Command).should be_true
      end

      it "non-strict mode should load the libraries using env var list" do
        ENV['BUNLDER_EXT_GROUPS'] = 'test development blah'
        ENV['BEXT_NOSTRICT'] = 'true'
        BundlerExt.system_require(@gemfile)
        defined?(Gem::Command).should be_true
      end

      unless skip_system
        context "ENV['BEXT_ACTIVATE_VERSIONS'] is true" do
          before(:each) do
            ENV['BUNDLER_EXT_NOSTRICT'] = 'true'
            ENV['BEXT_ACTIVATE_VERSIONS'] = 'true'
          end

          it "activates the version of the system installed package" do
            gems = BundlerExt.parse_from_gemfile(@gemfile, :all)
            gems.each { |gem,gdep|
              version = rand(100)
              BundlerExt.should_receive(:system_gem_name_for).with(gem).
                         and_return(gem)
              BundlerExt.should_receive(:system_gem_version_for).with(gem).
                         and_return(version)
              BundlerExt.should_receive(:gem).with(gem, "=#{version}")
            }
            BundlerExt.system_require(@gemfile, :all)
          end

          context "ENV['BEXT_PKG_PREFIX'] is specified" do
            it "prepends bundler pkg prefix onto system package name to load" do
              ENV['BEXT_PKG_PREFIX'] = 'rubygem-'
              gems = BundlerExt.parse_from_gemfile(@gemfile, :all)
              gems.each { |gem,gdep|
                BundlerExt.should_receive(:system_gem_version_for).with("rubygem-#{gem}").
                           and_return('0')
              }
              BundlerExt.system_require(@gemfile, :all)
            end
          end
        end
      end
    end
  end
