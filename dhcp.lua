--[[

   LUA script for dnsmasq DHCP leases. Modified from original source at:
   http://lists.thekelleys.org/pipermail/dnsmasq-discuss/2012q1/005425.html
   This script is principally a boilerplate example, to show what is possible...
   Tested using dnsmasq v2.90

   Run when:
     - Startup (existing leases are invoked with 'old' event 
     - SIGHUP ?
     - dhcp lease created, renewed, changed, or destroyed.
     - tftp file transfer completes (not tested)

   WHY?
   ====
   Gives us another way to monitor dhcp leases. 

   ENVIRONMENT VARIABLES
   =====================
     - DNSMASQ_DOMAIN 
     - DNSMASQ_SUPPLIED_HOSTNAME 
     - DNSMASQ_USER_CLASS0 ... _CLASSn
     - DNSMASQ_LEASE_LENGTH / DNSMASQ_LEASE_EXPIRES 
     - DNSMASQ_TIME_REMAINING
     - DNSMASQ_DATA_MISSING 
     - DNSMASQ_INTERFACE
     - DNSMASQ_RELAY_ADDRESS 
     - DNSMASQ_TAGS 
     - DNSMASQ_REQUESTED_OPTIONS 
     - DNSMASQ_MUD_URL
   - IPv4 Only
     - DNSMASQ_CLIENT_ID 
     - DNSMASQ_CIRCUIT_ID
     - DNSMASQ_SUBSCRIBER_ID
     - DNSMASQ_REMOTE_ID
     - DNSMASQ_VENDOR_CLASS
   - IPv6 Only
     - DNSMASQ_VENDOR_CLASS_ID
     - DNSMASQ_VENDOR_CLASS0 ... _CLASSn
     - DNSMASQ_SERVER_DUID 
     - DNSMASQ_IAID 
     - DNSMASQ_MAC

   FUNCTIONS & ARGUMENTS
   =====================
     - init
     - shutdown
     - lease
       - add
       - old
       - del
     - arp
       - arp-add	
       - old		???
       - del		???
     - relay-snoop	??? or is this relay(arg), where arg='snoop'?
     - tftp		??? 

   dnsmasq CONFIGURATION
   =====================
     dhcp-scriptuser = WHATEVER
     dhcp-luascript = /usr/local/etc/dnsmasq.d/THIS_SCRIPT.lua
     script-on-renewal
     script-arp

--]]


DBI = require "DBI"	-- The ONLY external dependency. On gentoo, use emerge dev-lua/luadbi (or use luarocks)

-- Variable Declarations
counter = 0
file = nil		-- writing to a normal file
dbh = nil		-- our database connection
dbinsert = nil		-- preprepared call to write to a database






local function myenv()	-- For testing. How do we retrieve the contents of the environment variables?
	a = (os.getenv("DNSMASQ_TIME_REMAINING") or "blank")
	return a
end

local function myerrorhandler(err)
	print("ERROR: " .. err)
end

function init(a)
	a = (a or "------------------------------\n")
	-- MOST of this function will need to be deleted or commented out, depending on what functionality is required.
	local ok, err, code = os.rename("/tmp/ilua.db","/tmp/ilua.db")
	if not ok then
		if code == 13 then
			print("DB File exists, but we can't open it! Please fix (or delete).")
			os.exit()
		else
			print("No DB file found. Creating...")
			os.execute('sqlite3 --line /tmp/ilua.db "CREATE TABLE table1(\"a\");"')
		end
	end

	print(a .. "Starting dnsmasq lua script...\n==============================\n")

	file = assert(io.open("/tmp/test.log", "a+"))
--	dbh = assert(DBI.Connect('PostgreSQL', 'db', 'user', 'password' ))	-- Alternative
	dbh = assert(DBI.Connect('SQLite3','/tmp/ilua.db'))
	dbh:autocommit(true)
--	dbinsert = assert(dbh:prepare('INSERT INTO table1(a) values ($1)'))	-- PostgreSQL
end

local function output(mystring)
	print(mystring)			-- In production, I see little point in this. Left for testing.
	file:write(mystring)		-- We write our data to a standard file...
	file:flush()			-- ... but it doesn't flush to file until after shutdown! :-(

	DBI.Do(dbh, "INSERT INTO table1(a) VALUES ('" .. mystring .. "');")	-- ... or a SQLite3 file ...
	-- dbinsert:execute(mystring)	-- ... or a database (if using postgreSQL)

	-- See: http:jpmens.net/2013/10/21/tracking-dhcp-leases-with-dnsmasq/
	local cmd = 'mosquitto_pub -h 192.168.1.2 -t "' .. "topic" .. '" -m "' .. "payload" .. '" -r'
	print(cmd .. "\n")			-- Edit, and change 'print' to 'os.execute'

	-- What else might we like to do?
end

function shutdown()
	-- This is not being called. Why?
	file:write("Stopping dnsmasq lua script..!\n==============================\n")
	file:close()
	-- dbinsert:close()		-- only needed if we have a prepared SQL insert function.
	dbh:close()
end

local function tabletostring(table)
	local k,v
	local line = ""
	for k,v in pairs(table) do line = line .. "\n" .. k  .. " = " .. v end
	return line
end

function lease(action, lease_desc)
	counter = counter + 1
--	status = xpcall(myenv, myerrorhandler)
--	print(status)
	local line = "Lua: " .. counter .. " " .. action .. " "
	for k,v in pairs(lease_desc) do line = line .. "\n" .. k .. " " .. v end
	line = line .. "\n"
	output(line)
end

function arp(a, b, c)	-- expected, but not tested: Action (string), Args (table)
	--b = type(b)
	c = type(c)
	local line = "-- arp " .. a .. " / " .. tabletostring(b) .. "\n" .. c .. "\n"
	output(line)
end

function arp_del()
	output("-- arp-del. \n")
end

function arp_old()
	output("-- arp-old. \n")
end

function tftp(a, b, c)	-- expected, but not tested: Action, table{destination addr, file name, file size}
	a = (a or '-')
	b = type(b)
	c = type(c)
	line = "-- tftp " .. a .. " / " .. b .. " / " .. c .. "\n"
	output(line)
end



-- Exit Codes: Does dnsmask log these anywhere?
   -- 0: Success
   -- 1: Configuration problem
   -- 2: Network access problem
   -- 3: Filesystem error (missing dir/file, incorrect permissions)
   -- 4: Memory allocation failure
   -- 5: Other (miscellaneous) problem




--[[
-- Used only for testing. REMOVE the third hyphen above when calling via dnsmasq.
table = {}
table["Example"]	= "NOT accurate representation of data in real life!"
table["domain"]		= "test.com"
table["hostname"]	= "laptop"
table["mac_address"]	= "01:23:45:67:89:ab"
table["ip_address"]	= "192.168.1.14"

init()
lease("old", table)
lease("add", table)
lease("del", table)
arp("arp-add", table)
arp("arp-del", table)
--tftp("test")
			-- no other calls seen in a working environment. this appears to be the lot.
shutdown()



--]]

--[[ Ideas

lua-cjson  vs  luajson
luasocket
toluapp

What's in the DB?
IP / Lease status / Start / End / MAC / DNS Name / WINS name
Subnet / Router

--]]

--[[
		+-----+-----+-----------------+
		|    arp    |      lease      | 
		+-----+-----+-----+-----+-----+
		| add | old | add | old | del |
================+=====+=====+=====+=====+=====+=====+
mac_address	|  y  |  y  |  y  |  y  |  y  |	
client_address	|  y  |  y  |     |     |     |	Either IPv4 addr or ?IPv6? address
client_id	|     |     |  *  |  *  |  *  |	derived from MAC addr. Not always present
lease_expires	|     |     |  y  |  y  |  y  |
time_remaining	|     |     |  y  |  y  |     |	If present, always '3600.0'
ip_address	|     |     |  y  |  y  |  y  |
hostname	|     |     |  y  |  y  |  y  |
domain		|     |     |  y  |  y  |  y  |
interface	|     |     |  y  |  y  |     |	
data_missing	|     |     |  y  |  y  |     |	if present, always '1.0'
      		|     |     |     |     |     |
----------------+-----+-----+-----+-----+-----+-----+

--]]
