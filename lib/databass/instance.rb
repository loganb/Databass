require 'fileutils'

#
# The Postgres instance on the local filesystem. Has methods to start/stop the 
# DB, look up its status, etc
#
#
class Databass::Instance
	attr_reader :path
	attr_reader :port

	def initialize(data_path, port = 5432)
		@path = File.expand_path data_path
		@port = port
	end

	#
	# true if an instance of postgres already exists here
	#
	def exists?
		File.exists?(File.join(path, 'PG_VERSION'))
	end

	def slave?
		File.exists?(recovery_file)
	end

	#
	# Creates a new master Postgres instance (in master mode)
	#
	# @param master A string in the format 'host:port' referring to the master
	#
	def init!(master = nil)
		raise "Already exists!" if exists?

		FileUtils.mkdir_p(path)
		FileUtils.chmod(0700, path)
		raise "Could not create data directory" unless File.exists? path

		if(master.nil?) #initialization of a blank instance
			#This creates all the DB files
			Databass.pg_ctl(path, :init)

			#Moves the default config files aside so that they can be regenerated on demand
			FileUtils.mv(conf_file, conf_file('default'))
			FileUtils.mv(hba_file, hba_file('default'))
		else #initialization from a master
			Databass.pg_basebackup(path, master)

			generate_recovery_config!(master)
		end

		true
	end


	#
	# Starts the DB instance
	#
	# @option mode [Symbol] TBD, optional for now
	#
	def start!(mode = nil)
		raise "Server must be stopped" unless status == :stopped

		generate_config! unless slave?

		Databass.pg_ctl(path, :start, '-w', '-o', "-c port=#{port}")
	end

	def stop!
		raise "Server must be running" unless status == :running

		Databass.pg_ctl(path, :stop, '--mode=fast')
	end

	def generate_config!
		raise unless status == :stopped
		
		c = [File.read(conf_file('default')), conf_config].join("\n")
		File.write(conf_file, c)

		hba = [File.read(hba_file('default')), hba_config].join("\n")
		File.write(hba_file, hba, mode: 'w')
	end

	#
	# Current status of instance. Possible values are: 
	#   :stopped
	#   :running
	#
	# @return [Symbol] :stopped if the DB is not running
	#
	#
	def status
		case (s = Databass.pg_ctl(path, :status))
		when 3 then :stopped
		when 0 then :running
		else raise "Unknown response from pg_ctl status: #{s}"
		end
	end

	protected

	def generate_recovery_config!(master)
		host,port = master.split(':')

		File.write(recovery_file, <<EOS, mode: 'w')
standby_mode = 'on'
primary_conninfo = 'host=#{host} port=#{port}'

EOS
	end

	def db_path
		File.join(path, 'pg')
	end

	def conf_file(suffix = nil)
		File.join(path, ["postgresql.conf",suffix].compact.join('.'))
	end

	def hba_file(suffix = nil)
		File.join(path, ['pg_hba.conf', suffix].compact.join('.'))
	end

	def recovery_file
		File.join(path, 'recovery.conf')
	end

	def hba_config
		<<EOF
host    replication     all             all        trust
EOF
	end

	def conf_config
		<<EOS
# It's not sensical to run a cluster with more than 3 nodes, giving two extra connections for spinning up new capacity
max_wal_senders = 5
wal_level = hot_standby
wal_keep_segments = 1000
hot_standby = on
EOS
	end
end