import QtQuick 2.15
import org.kde.plasma.plasma5support 2.0 as P5Support
import org.kde.plasma.plasmoid 2.0
import "../DeviceUtils.js" as DeviceUtils

// OpenLinkHub device provider v 1.0.0
//  	 (\_/)
//	  	 ('.')
//		|"   "|
//		|     |
// 	AzzyBunn was here
Item {
	id: root
	visible: false
	
	property var devices: []
	property bool available: false

	property int port: Plasmoid.configuration.openLinkHubApiPort

	function refresh() {
		devices = []
		if(!plasmoid.configuration.enableOpenLinkHubIntegration){return} //Allows clearing device list after configuration was disabled
		fetchBatteryData()
	}

	// Step 1: Send a HTML request to localhost:[port] asking about battery information
	function fetchBatteryData(){
		var req = new XMLHttpRequest();
		
		// Step 1.1: Filter HTTP ready states and responses
		req.onreadystatechange = () => {
			if (req.readyState === XMLHttpRequest.DONE) {				
				if(!req.response){return}
				var response = JSON.parse(req.response) // Step 1.2: Parse the HTTP response
				var batteryData = response.data
				if(!batteryData){
					console.log("Server responded without any battery data!");
					return
				}
				available = true //Server responded with data about battery -> service available
				processBatteryData(batteryData); // Battery data -> Step 2
			}
		}

		// Step 1.3: Send request
		req.open("GET", "http://127.0.0.1:"+port+"/api/batteryStats");
		req.send();
	}

	// Step 2: Process the received battery data
	function processBatteryData(data){
		// Step 2.1: Extract the ID of a device and discard the rest.
		//Wasteful, I know. But it's better than forwarding all the data we're gonna get again anyways.
		var deviceIDs = Object.keys(data);

		// Step 2.2: Request each device's full data. The only usefull thing here that's not on /api/batteryStats is the Connection satus.

		// If the device is missing the 'Connected' field it probably means it's wired.
		// My mouse stopped supplying 'Connected' field when connected to a pc. Probably just switched to usb mode.
		deviceIDs.forEach((deviceID) => {
			fetchDeviceData(deviceID, data[deviceID].DeviceType);
		})
	}

	// Step 2.2.1: Send a HTML request to localhost:[port] asking for deails about a device
	function fetchDeviceData(deviceID, type){
		var req = new XMLHttpRequest();
		
		// Step 2.2.1: Filter HTTP ready states and responses
		req.onreadystatechange = () => {
			if (req.readyState === XMLHttpRequest.DONE) {
				if(!req.response){return}
				var response = JSON.parse(req.response) // Step 2.2.2: Parse the HTTP response
				var batteryData = response.device
				if(!response.device){
					console.log("Server responded without any device data!");
					return
				}
				parseDeviceData(response.device, type); // Step 2.2.3: Parse the device data
			}
		}

		req.open("GET", "http://127.0.0.1:"+port+"/api/devices/"+deviceID);
		req.send();
	}

	// Step 2.2.3: Parse the device data
	function parseDeviceData(data, type){
		// Step 2.2.3.1.... or 3.1: Check if device is connected
		if(!data.Connected){return}
		// Step 3.2: Setup device info
		var device = {
			name: data.product,
			serial: data.serial,
			percentage: data.BatteryLevel,
			type: "",
			icon: "battery-symbolic",

			//Static
			source: "openlinkhub",
			connectionType: 2, //Always wireless if passed to the device list

			//Not applicable to OpenLinkHub devices
			model: null,
			objectPath: null,
			nativePath: null,
			bluetoothAddress: null,
			batteries: [], // Maybe usable? Look at Step 2.2 for comment.
		}

		// Step 3.3: Set device's type and icon
		switch (type) { //Check device's type
			case 2:
				device.type = "headset"
				break;
			case 1:
				device.type = "mouse"
				break;
			case 0:
				device.type = "keyboard"
				break;
			default:
				device.type = ""
		}

		device.icon = DeviceUtils.getIconForType(device.type)

		// Step 3.3: Push the device to the current device list
		devices.push(device)
	}

	
	// Poll frequently when service is available, probe slowly when not
	Timer {
		interval: root.available ? 10000 : 60000
		running: true
		repeat: true
		onTriggered: root.refresh()
	}

	Component.onCompleted: root.refresh()
}
