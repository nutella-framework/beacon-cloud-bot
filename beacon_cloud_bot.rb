require 'nutella_lib'
require 'json'


# Initialize nutella
nutella.init("crepe", "localhost", "beacon-cloud-bot")

puts "Beacon cloud initialization"

# Open the resources database
beacons = nutella.persist.getJsonStore("db/beacons.json")

# Contains virtual beacon codes that are created for iPads
virtualBeacons = {}
major = 0
minor = 0
uuid = '00000000-0000-0000-0000-000000000000'

# Create new beacon
nutella.net.subscribe("beacon/beacon/add", lambda do |message, component_id, resource_id|
										puts message
										rid = message["rid"]
										uuid = message["uuid"]
										major = message["major"]
										minor = message["minor"]

										if rid != nil && uuid != nil && major != nil && minor != nil
											beacons.transaction {
												if beacons[rid] == nil
													beacons[rid] = {
														:rid => rid,
														:uuid => uuid,
														:major => major,
														:minor => minor
													}

													publishBeaconAdd(beacons[rid])
													puts("Added beacon")
												end
											}
										end
									end)

# Create new beacon
nutella.net.subscribe("beacon/beacon/remove", lambda do |message, component_id, resource_id|
										puts message
										rid = message["rid"]

										if rid != nil
											beacons.transaction {
												if beacons[rid] != nil
													beacon = beacons[rid]

													beacons.delete(rid)

													publishBeaconRemove(beacon)
													puts("Removed resource")
												end
											}
										end
									end)

# Publish an added beacon
def publishBeaconAdd(beacon)
	puts beacon
	nutella.net.publish("beacon/beacons/added", {:beacons => [beacon]});
end

# Publish an remove beacon
def publishBeaconRemove(beacon)
	puts beacon
	nutella.net.publish("beacon/beacons/removed", {:beacons => [beacon]});
end

# Request all the beacons
nutella.net.handle_requests("beacon/beacons", lambda do |request, component_id, resource_id|
	puts "Send the beacon list"
	beaconList = []
	beacons.transaction {
		for beacon in beacons.roots()
			beaconList.push(beacons[beacon])
		end
	}

  virtualBeacons.each do |key, beacon|
    beaconList.push(virtualBeacons[beacon])
  end
	{:beacons => beaconList}
end)

# Request all the UUIDs
nutella.net.handle_requests("beacon/uuids", lambda do |request, component_id, resource_id|
	puts "Send the uuid list"
	uuidList = []
	beacons.transaction {
		for beacon in beacons.roots()
			if !uuidList.include? beacons[beacon]["uuid"]
				uuidList.push(beacons[beacon]["uuid"])
			end
		end
	}
	{:uuids => uuidList}
end)

# Request virtual beacon codes
nutella.net.handle_requests("beacon/virtual_beacon", lambda do |request, component_id, resource_id|
  if request["rid"] != nil
    rid = request["rid"]
    virtualBeacon = virtualBeacons[rid]
    if virtualBeacon == nil
      puts "Create new virtual beacon major: #{major}, minor: #{minor}"
      virtualBeacons[rid] = {
          :rid => rid,
          :uuid => uuid,
          :major => major,
          :minor => minor,
          :virtual => true
      }
      minor += 1
      if minor != minor % 65536
        major += 1
      end
      minor = minor % 65536
      virtualBeacon = virtualBeacons[rid]
      publishBeaconAdd(virtualBeacon)
      puts("Added virtual-beacon")
    end
    virtualBeacon
  end
end)

puts "Initialization completed"

# Just sit there waiting for messages to come
nutella.net.listen
