require "databass/version"
require 'databass/instance'

require 'zookeeper'

module Databass
  
  def self.server(zk, cluster_name, data_path)

  	zk.create("/databass")

  end


  def self.pg_config(*args)
  	@pg_config ||= `pg_config #{args.join(' ')}`.split("\n").reduce({}) do |memo, line| 
  		line.split(/\s*=\s*/).tap { |k,v| memo[k.strip.to_sym] = v }
  		memo
  	end
  end

  def self.pg_version
  	Gem::Version.new(pg_config[:VERSION].match(/PostgreSQL (\d+\.\d+\.\d+)/)[1])
  end

  def self.pg_bindir
  	pg_config[:BINDIR]
  end

  def self.pg_ctl(location, cmd, *args)
  	pid = spawn({"PGDATA" => location}, File.join(pg_bindir,'pg_ctl'), cmd.to_s, *args)
  	Process.wait(pid)
  	status = $?

  	case(cmd)
  	when :status then status.exitstatus #pg_ctl status returns server status through return code
  	else
	  	raise "pg_ctl failed with code #{status.exitstatus}" unless status.exitstatus == 0
	  	nil
	  end
  end

  def self.pg_basebackup(location, server)
    host,port = server.split(':')

    pid = spawn(File.join(pg_bindir, 'pg_basebackup'), '-D', location, '-h', host, '-p', port, '-x')
    Process.wait(pid)
    status = $?

    raise "pg_basebackup failed with code #{status.exitstatus}" unless status.exitstatus == 0
    nil    
  end

  def self.psql(server, database, cmd)
    host,port = server.split(':')

    pid = spawn(File.join(pg_bindir, 'psql'), '-h', host, '-p', port, '-c', cmd, database)
    Process.wait(pid)
    status = $?

    raise "pg_basebackup failed with code #{status.exitstatus}" unless status.exitstatus == 0
    nil    
  end
end
