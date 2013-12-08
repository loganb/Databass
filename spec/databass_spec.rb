require_relative './spec_helper'

require 'tmpdir'

describe Databass do
	describe ".pg_config" do
		subject { described_class.pg_config }

		it { should be_a(Hash) }
		it { should_not be_empty }
	end

	describe ".pg_version" do
		subject { described_class.pg_version }

		it { should be_a Gem::Version }

		it "should be a recent version" do
			should be > Gem::Version.new('9.0')
		end
	end

	describe ".pg_bindir" do
		subject { described_class.pg_bindir }
		it { should be_a String }
	end

	describe ".pg_ctl" do
		let(:tmpdir) { File.join(Dir.tmpdir, "databass-spec-#{UUIDTools::UUID.random_create}") }

		it 'runs pg_ctl' do
			described_class.pg_ctl('/', '--help')
		end
	end
end