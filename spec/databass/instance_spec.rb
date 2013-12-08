require_relative '../spec_helper'

require 'uuidtools'
require 'tmpdir'

describe Databass::Instance do

	#A unique path for creating new instances
	let(:path) { File.join(Dir.tmpdir, "databass-spec-#{UUIDTools::UUID.random_create}") }
	subject { described_class.new(path) }

	context "A new instance" do
	
		it { should_not exist }

		describe "#init!" do
			it "creates the DB" do
				subject.init!
				subject.should exist
			end
		end

		describe '#status' do
			its(:status) { should == :stopped }
		end
	end

	context "an existing instance" do
		before(:each) { subject.init! }

		describe "#init!" do
			it "doesn't overwrite an existing DB" do
				subject.should exist
				expect { subject.init! }.to raise_error
			end

			it "includes a recovery line in pg_hba.conf" do
				subject.generate_config!
				File.read(File.join(path, "pg_hba.conf")).should match(/replication/)
			end
		end

		describe "#status" do
			its(:status) { should == :stopped }
		end

		describe "#start!" do
			after(:each) { subject.stop! rescue nil }

			it 'starts a server' do
				subject.start!
				subject.status.should == :running
			end

			it "doesn't start twice" do
				subject.start!
				expect { subject.start! }.to raise_error
			end
		end
	end

	context "replicating from a master" do
		let(:master) { @master }

		before(:all) do
			master_path = File.join(Dir.tmpdir, "databass-spec-#{UUIDTools::UUID.random_create}")
			master = described_class.new(master_path, 5433)

			master.init!
			master.start!
			@master = master
		end
		after(:all) { @master.stop! }

		before(:each) {
			subject.init!('localhost:5433')
		}
		after(:each) { subject.stop! if subject.status == :running }

		it 'starts' do 
			subject.start!
		end

		it { should be_a_slave }
	end

end