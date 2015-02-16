require 'nutella_lib'
require 'json'


# Initialize nutella
nutella.init ARGV

puts "Room places initialization"

# Open the resources database
beacons = nutella.persist.getJsonStore("db/beacons.json")

# Create new beacon
nutella.net.subscribe("beacon/beacon/add", lambda do |message|
										puts message;
										rid = message["rid"]
										uuid = message["uuid"]
										major = message["major"]
										minor = message["minor"]

										if(rid != nil && uuid != nil && major != nil && minor != nil)
											beacons.transaction {
												if(beacons[rid] == nil)
													beacons[rid] = {
														"rid" => rid,
														"uuid" => uuid,
														"major" => major,
														"minor" => minor
													}

													publishBeaconAdd(beacons[rid]);
													puts("Added beacon")
												end
											}
										end
									end)

# Create new beacon
nutella.net.subscribe("beacon/beacon/remove", lambda do |message|
										puts message;
										rid = message["rid"]

										if(rid != nil)
											beacons.transaction {
												if(beacons[rid] != nil)
													beacon = beacons[rid]

													beacons.delete(rid)

													publishBeaconRemove(beacon);
													puts("Removed resource")
												end
											}
										end
									end)

# Publish an added beacon
def publishBeaconAdd(beacon)
	puts beacon
	nutella.net.publish("beacon/beacons/added", {"beacons" => [beacon]});
end

# Publish an remove beacon
def publishBeaconRemove(beacon)
	puts beacon
	nutella.net.publish("beacon/beacons/removed", {"beacons" => [beacon]});
end

# Request all the beacons
nutella.net.handle_requests("beacon/beacons") do |request|
	puts "Send the beacon list"
	beaconList = []
	beacons.transaction {
		for beacon in beacons.roots()
			beaconList.push(beacons[beacon])
		end
	}
	{"beacons" => beaconList}
end

# Request all the UUIDs
nutella.net.handle_requests("beacon/uuids") do |request|
	puts "Send the uuid list"
	uuidList = []
	beacons.transaction {
		for beacon in beacons.roots()
			if(!uuidList.include? beacons[beacon]["uuid"])
				uuidList.push(beacons[beacon]["uuid"])
			end
		end
	}
	{"uuids" => uuidList}
end

puts "Initialization completed"

# Just sit there waiting for messages to come
nutella.net.listen
